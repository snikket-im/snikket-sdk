package snikket;

import snikket.queries.PubsubGet;
import snikket.queries.PubsubPublish;

import haxe.crypto.Base64;
import haxe.io.Bytes;

import thenshim.Promise;
import thenshim.PromiseTools;

using snikket.SignalProtocol;

@:structInit
class OMEMOBundleSignedPreKey {
	public final id: Int;
	public final public_key: String;
	public final signature: String;
}

@:structInit
class OMEMOBundle {
	public final identity_key: String;
	public final device_id: Int;
	public final prekeys: Array<PublicPreKey>;
	public final signed_prekey: OMEMOBundleSignedPreKey;

	public function new(identity_key:String, device_id:Int, prekeys:Array<PublicPreKey>, signed_prekey:OMEMOBundleSignedPreKey) {
		this.identity_key = identity_key;
		this.device_id = device_id;
		this.prekeys = prekeys;
		this.signed_prekey = signed_prekey;
	}

	public function toXml():Stanza {
		var bundleTag = new Stanza("bundle", { xmlns: "eu.siacs.conversations.axolotl" });
		bundleTag.textTag("signedPreKeyPublic", signed_prekey.public_key, { signedPreKeyId: Std.string(signed_prekey.id) });
		bundleTag.textTag("signedPreKeySignature", signed_prekey.signature);
		bundleTag.textTag("identityKey", identity_key);

		bundleTag.tag("prekeys");
		for (prekey in prekeys) {
			bundleTag.textTag("preKeyPublic", prekey.pubKey, { preKeyId: Std.string(prekey.keyId) });
		}
		bundleTag.up();
		return bundleTag;
	}
}

class OMEMO {
	private final client: Client;
	private final persistence: Persistence;

	// Track the status of our bundle state locally
	private final bundleLocalState:FSM;

	// Track the status of our account's PEP node
	private final bundlePublicState:FSM;

	private var bundle: OMEMOBundle;

	// An array of all our device IDs on our account
	public var deviceList:Array<Int>;

	// Recommended number of prekeys, per the XEP
	private final NUM_PREKEYS = 100;
	private static final publicNodeConfig:PubsubConfig = {
		max_items: 1,
		access_model: "open",
		publish_model: "publishers",
		persist_items: true,
		send_last_published_item: "on_sub_and_presence",
	};

	public function new(client_: Client, persistence_: Persistence) {
		client = client_;
		persistence = persistence_;

		 bundleLocalState = new FSM({
			transitions: [
				{ name: "loaded", from: ["loading"], to: "ok" },
				{ name: "missing", from: ["loading"], to: "creating" },
				{ name: "created", from: ["creating"], to: "ok" },
			],
			state_handlers: [
				"loading" => loadBundle,
				"creating" => createLocalBundle,
			],
			transition_handlers: [
			],
		}, "loading");

		 bundlePublicState = new FSM({
			transitions: [
				{ name: "verify", from: ["unverified"], to: "verifying" },
				{ name: "needs-update", from: ["unverified", "verifying", "waiting", "updating", "ok"], to: "updating" },
				{ name: "wait", from: ["updating"], to: "waiting" },
				{ name: "updated", from: ["updating"], to: "ok" },
				{ name: "verified", from: ["unverified", "verifying"], to: "ok" },
			],
			state_handlers: [
				"verifying" => verifyPublishedBundle,
				"waiting" => waitForBundleReady,
				"updating" => updatePublishedBundle,
			],
			transition_handlers: [
			],
		}, "unverified");

		client.on("session-started", function (event) {
			bundlePublicState.event("verify");
			return EventHandled;
		});
	}

	private function loadBundle(event) {
		var bundleSignedPreKey:OMEMOBundleSignedPreKey;
		var newBundle = {
			identity_key: null,
			device_id: null,
			prekeys: null,
			signed_prekey: null,
		};

		final pDeviceId = new Promise(function (resolve, reject) {
			persistence.getOmemoId(client.accountId(), resolve);
		}).then(function (storedDeviceId) {
			if(storedDeviceId == null) {
				// We don't have an OMEMO identity, so we need
				// to create all our state and publish it
				return false;
			}
			trace("Using existing OMEMO identity");
			newBundle.device_id = storedDeviceId;
			return true;
		});

		final pIdentityKey = new Promise(function (resolve, reject) {
			persistence.getOmemoIdentityKey(client.accountId(), resolve);
		}).then(function (storedIdentityKey) {
			if(storedIdentityKey == null) {
				trace("No identity key stored");
				this.bundleLocalState.event("missing");
				return false;
			}
			trace("Loaded identity key");
			newBundle.identity_key = Base64.encode(Bytes.ofData(storedIdentityKey.pubKey));
			return true;
		});

		final pSignedPreKey = new Promise(function (resolve, reject) {
			persistence.getOmemoSignedPreKey(client.accountId(), 1, resolve);
		}).then(function (signedPreKey) {
			if(signedPreKey == null) {
				trace("No signed prekey stored");
				return false;
			}
			trace("Loaded signed prekey");
			newBundle.signed_prekey = signedPreKey;
			return true;
		});

		final pPreKeys = new Promise(function (resolve, reject) {
			persistence.getOmemoPreKeys(client.accountId(), resolve);
		}).then(function (prekeys) {
			// Always an array (just empty if no keys)
			newBundle.prekeys = [
				for(i in 0...prekeys.length) {
					{
						keyId: i+1,
						pubKey: Base64.encode(Bytes.ofData(prekeys[i].pubKey)),
					};
				}
			];
			trace("Loaded "+Std.string(prekeys.length)+" prekeys");
			return true;
		});

		PromiseTools.all([pDeviceId, pIdentityKey, pSignedPreKey, pPreKeys]).then(function (results) {
			if(results.contains(false) || !bundleLocalState.can("loaded")) {
				trace("Problems loading OMEMO bundle or interrupted");
				this.bundleLocalState.event("missing");
				return false;
			}
			trace("OMEMO bundle successfully loaded from storage");
			this.bundle = new OMEMOBundle(
				newBundle.identity_key,
				newBundle.device_id,
				newBundle.prekeys,
				newBundle.signed_prekey
			);
			bundleLocalState.event("loaded");
			return true;
		});
	}


	private function createLocalBundle(event) {
		trace("Generating OMEMO identity for new device");
		buildBundle().then(function (ok:Bool) {
			if (!ok || !bundleLocalState.can("created")) {
				trace("Bundle creation failed");
				return;
			}
			bundleLocalState.event("created");
			// Signal that we need to publish the new bundle
			this.bundlePublicState.event("needs-update");
		});
	}

	// Wait for our local bundle to be ready for publication
	private function waitForBundleReady(event) {
		if(bundleLocalState.getState() == "ok") {
			// No need to wait!
			bundlePublicState.event("needs-update");
			return;
		}

		bundleLocalState.once("enter/ok", function (event) {
			bundlePublicState.event("needs-update");
			return EventHandled;
		});
	}

	private function verifyPublishedBundle(event) {
		trace("Verifying published OMEMO bundle");
		final deviceListGet = new PubsubGet(null, "eu.siacs.conversations.axolotl.devicelist");
		deviceListGet.onFinished(() -> {
			final devices = deviceIdsFromPubsubItems(deviceListGet.getResult());
			if(devices != null && devices.contains(this.bundle.device_id)) {
				bundlePublicState.event("verified");
			} else {
				bundlePublicState.event("needs-update");
			}
		});
		client.sendQuery(deviceListGet);
	}

	private function updatePublishedBundle(event) {
		if(bundleLocalState.getState() != "ok") {
			trace("Can't publish yet - waiting for local bundle");
			bundlePublicState.event("wait");
			return;
		}
		trace("Going to publish our bundle...");
		publishBundle();
	}

	private function deviceIdsFromPubsubItems(items:Array<Stanza>):Null<Array<Int>> {
		if(items.length == 0) {
			return null;
		}
		var devicelist = items[0].getChild("list", "eu.siacs.conversations.axolotl");
		if (devicelist == null) {
			return null;
		}

		var devices = [];
		for (device in devicelist.allTags("device", null)) {
			var device_id = Std.parseInt(device.attr.get("id"));
			if (device_id != null) {
				devices.push(device_id);
			}
		}
		return devices;
	}

	// Called when we receive an updated device list for our own account
	public function onAccountUpdatedDeviceList(items:Array<Stanza>) {
		trace("OMEMO: onAccountUpdatedDeviceList");
		// XEP-0384 (v0.3.0 section 4.3):
		// To mitigate this, devices MUST check that their own device ID is contained in the list
		// whenever they receive a PEP update from their own account. If they have been removed,
		// they MUST reannounce themselves.
		var devices = deviceIdsFromPubsubItems(items);
		if(devices == null || !devices.contains(bundle.device_id)) {
			trace("Incomplete or empty device list");
			publishDeviceList();
		} else {
			trace("Excellent... this device is already in the published device list");
		}
	}

	// Called when one of our contacts has published an updated device list
	public function onContactUpdatedDeviceList(contact:JID, items:Array<Stanza>) {
		trace("OMEMO: onContactUpdatedDeviceList: "+items[0]);
		var identifier = contact.asBare().asString();
		var chat = client.getDirectChat(identifier);
		var devices = deviceIdsFromPubsubItems(items);
		if(devices != null) {
			chat.omemoContactDeviceIDs = devices;
			persistence.storeChat(client.accountId(), chat);
		}
	}

	
	private function publishDeviceList() {
		if(deviceList == null) {
			deviceList = [bundle.device_id];
		} else if(!deviceList.contains(bundle.device_id)) {
			deviceList.push(bundle.device_id);
		}
		var deviceListTag = new Stanza("list", { xmlns: "eu.siacs.conversations.axolotl" });
		for(deviceId_ in deviceList) {
			deviceListTag.tag("device", { id: Std.string(deviceId_) }).up();
		}
		var publish = new PubsubPublish(null, "eu.siacs.conversations.axolotl.devicelist", "current", deviceListTag, publicNodeConfig);
		publish.onFinished(
			() -> {
				if (!publish.success) {
					trace("Failed to publish updated OMEMO device list: "+publish.error.condition);
				}
				trace("OMEMO device list published!");
				bundlePublicState.event("updated");
			}
		);
		client.sendQuery(publish);
	}
	
	private function publishBundle() {
		final bundleTag = bundle.toXml();
		final nodeName = "eu.siacs.conversations.axolotl.bundles:" + Std.string(bundle.device_id);
		final publish = new PubsubPublish(null, nodeName, "current", bundleTag, publicNodeConfig);
		publish.onFinished(
			() -> {
				if (!publish.success) {
					trace("Failed to publish our OMEMO device bundle: " + publish.error.condition);
				} else {
					trace("Published bundle!");
					if(deviceList == null || !deviceList.contains(bundle.device_id)) {
						trace("Need to also publish updated devicelist");
						publishDeviceList();
					}
				}
			}
		);
		client.sendQuery(publish);
	}

	// Stuff that touches libsignal

	// Build and store an OMEMO identity bundle
	private function buildBundle():Promise<Bool> {
		final deviceId = KeyHelper.generateRegistrationId(); // FIXME: Check for collision
		var identityKeyPair:IdentityKeyPair;
		var signedPreKey:SignedPreKey;
		var prekeys:Array<PublicPreKey>;

		final identityKeyPairPromise:Promise<IdentityKeyPair> = KeyHelper.generateIdentityKeyPair();

		final doneIdentityStorage:Promise<Bool> = identityKeyPairPromise.then(function (keypair:IdentityKeyPair):Bool {
			identityKeyPair = keypair;
			persistence.storeOmemoId(client.accountId(), deviceId);
			persistence.storeOmemoIdentityKey(client.accountId(), keypair);
			return true;
		});
		
		final preKeysPromise:Promise<Array<PublicPreKey>> = doneIdentityStorage.then(cast generatePreKeys);

		return preKeysPromise.then(function (prekeys_:Array<PublicPreKey>):Promise<SignedPreKey> {
			// Store prekeys array for publication in a moment
			prekeys = prekeys_;
			
			return KeyHelper.generateSignedPreKey(identityKeyPair, 0);
		}).then(cast function (signedPreKey:SignedPreKey):Bool {
			// store.js:283
			final stored_signed_prekey:OMEMOBundleSignedPreKey = {
					id: signedPreKey.keyId,
					public_key: Base64.encode(Bytes.ofData(signedPreKey.keyPair.pubKey)),
					signature: Base64.encode(Bytes.ofData(signedPreKey.signature)),
			};
			persistence.storeOmemoSignedPreKey(client.accountId(), stored_signed_prekey);
			
			this.bundle = {
				identity_key: Base64.encode(Bytes.ofData(identityKeyPair.pubKey)),
				device_id: deviceId,
				prekeys: prekeys,
				signed_prekey: stored_signed_prekey,
			};
			return true;
		});
	}

	private function generatePreKeys(_:Bool):Promise<Array<PublicPreKey>> {
		final amount = NUM_PREKEYS;
		final keys = [];

		final generatedPreKeys:Promise<Array<PreKey>> = PromiseTools.all([
			for(i in 1...(amount+1)) {
				trace("Generating prekey "+Std.string(i));
				KeyHelper.generatePreKey(i);
			}
		]);

		final publicStoredPreKeys:Promise<Array<PublicPreKey>> = cast generatedPreKeys.then(cast function (prekeys:Array<PreKey>):Array<PublicPreKey> {
			for(prekey in prekeys) {
				// Store the full keypair
				persistence.storeOmemoPreKey(client.accountId(), prekey.keyId, prekey.keyPair);
			}
			return [
				for(prekey in prekeys) {
					// Emit the base64 public part for the application to publish
					{
						keyId: prekey.keyId,
						pubKey: Base64.encode(Bytes.ofData(prekey.keyPair.pubKey))
					};
				}
			];
		});

		return publicStoredPreKeys;
	}
}
