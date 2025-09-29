package borogove;

import haxe.io.BytesBuffer;
import borogove.EncryptedMessage;
import borogove.Message;

import borogove.queries.PubsubGet;
import borogove.queries.PubsubPublish;

import haxe.crypto.Base64;
import haxe.io.Bytes;
import haxe.io.BytesData;

import thenshim.Promise;
import thenshim.PromiseTools;

using borogove.SignalProtocol;

#if js
import js.Browser;
#end

@:structInit
class OMEMOBundleSignedPreKey {
	public final id: Int;
	public final public_key: String;
	public final signature: String;

	static public function fromSignedPreKeyPair(signedPreKey:SignedPreKey):OMEMOBundleSignedPreKey {
		final bundlePreKey:OMEMOBundleSignedPreKey = {
			id: signedPreKey.keyId,
			public_key: Base64.encode(Bytes.ofData(signedPreKey.keyPair.pubKey)),
			signature: Base64.encode(Bytes.ofData(signedPreKey.signature)),
		};
		return bundlePreKey;
	}
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

	static public function fromXml(stanza:Stanza, deviceId:Int):OMEMOBundle {
		return {
			identity_key: stanza.getChildText("identityKey"),
			device_id: deviceId,
			signed_prekey: {
				id: Std.parseInt(stanza.findText("signedPreKeyPublic@signedPreKeyId")),
				public_key: stanza.getChildText("signedPreKeyPublic"),
				signature: stanza.getChildText("signedPreKeySignature"),
			},
			prekeys: [
				for(keyTag in stanza.getChild("prekeys").allTags("preKeyPublic")) {
					{
						keyId: Std.parseInt(keyTag.attr.get("preKeyId")),
						pubKey: keyTag.getText(),
					}
				}
			],
		}
	}

	public function getRandomPreKey():PublicPreKey {
		return prekeys[Std.random(prekeys.length-1)];
	}

	// Return a new bundle with an updated set of prekeys
	public function withNewPreKeys(newPreKeys:Array<PublicPreKey>):OMEMOBundle {
		return new OMEMOBundle(this.identity_key, this.device_id, newPreKeys, this.signed_prekey);
	}
}

class OMEMOStore extends SignalProtocolStore {
	private final accountId: String;
	private final persistence: Persistence;

	public function new(accountId:String, persistence:Persistence) {
		this.accountId = accountId;
		this.persistence = persistence;
	}

	// Load the identity keypair for our account
	public function getIdentityKeyPair():Promise<IdentityKeyPair> {
		return persistence.getOmemoIdentityKey(accountId);
	}

	public function getLocalRegistrationId():Promise<Int> {
		return persistence.getOmemoId(accountId);
	}

	public function isTrustedIdentity(identifier:String, identityKey:IdentityPublicKey, _direction:Int):Promise<Bool> {
		return Promise.resolve(true); // FIXME?
	}

	// Load the identity key of a contact (partners with saveIdentity())
	public function loadIdentityKey(identifier:SignalProtocolAddress):Promise<IdentityPublicKey> {
		return persistence.getOmemoContactIdentityKey(accountId, identifier.toString());
	}

	public function saveIdentity(identifier:SignalProtocolAddress, identityKey:IdentityPublicKey):Promise<Bool> {
		return persistence.getOmemoContactIdentityKey(accountId, identifier.toString()).then((prevKey) -> {
			persistence.storeOmemoContactIdentityKey(accountId, identifier.toString(), identityKey);
			// Return true if the key was updated, false if it matches what we already had stored
			return prevKey != identityKey;
		});
	}

	public function loadPreKey(keyId:Int):Promise<PreKeyPair> {
		return persistence.getOmemoPreKey(accountId, keyId);
	}

	

	public function storePreKey(keyId:Int, keyPair:PreKeyPair):Promise<Bool> {
		persistence.storeOmemoPreKey(accountId, keyId, keyPair);
		return Promise.resolve(true);
	}

	public function removePreKey(keyId:Int):Promise<Bool> {
		trace("OMEMO: Removing prekey "+keyId);
		persistence.removeOmemoPreKey(accountId, keyId);
		// FIXME: Need to signal that we need to generate a replacement
		// for the consumed prekey and republish our bundle
		return Promise.resolve(true);
	}

	public function loadSignedPreKey(keyId:Int):Promise<PreKeyPair> {
		trace("OMEMO: Loading signed prekey "+keyId);
		return persistence.getOmemoSignedPreKey(accountId, keyId).then((signedPreKey) ->
			signedPreKey.keyPair
		);
	}

	public function storeSignedPreKey(keyId:Int, keyPair:SignedPreKey):Promise<Bool> {
		trace("OMEMO: Storing signed prekey "+keyId);
		persistence.storeOmemoSignedPreKey(accountId, keyPair);
		return Promise.resolve(true);
	}

	public function removeSignedPreKey(keyId:Int):Promise<Bool> {
		throw new haxe.exceptions.NotImplementedException();
	}

	public function loadSession(identifier:SignalProtocolAddress):Promise<SignalSession> {
		return persistence.getOmemoSession(accountId, identifier.toString());
	}

	public function storeSession(identifier:SignalProtocolAddress, session:SignalSession):Promise<Bool> {
		persistence.storeOmemoSession(accountId, identifier.toString(), session);
		return Promise.resolve(true);
	}

	public function removeSession(identifier:SignalProtocolAddress):Promise<Bool> {
		throw new haxe.exceptions.NotImplementedException();
	}

	public function removeAllSessions(identifier:SignalProtocolAddress):Promise<Bool> {
		throw new haxe.exceptions.NotImplementedException();
	}
}

@:structInit
class OMEMOPayloadKey {
	// FIXME: Add identifier here, required for OMEMO 2
	public final rid:Int;
	public final prekey:Bool;
	public final encodedKey:String;

	public function getRawKey():BytesData {
		return Base64.decode(encodedKey).getData();
	}
}

// Represents an OMEMO payload in a message
@:structInit
class OMEMOPayload {
	public final sid:Int;
	public final keys:Array<OMEMOPayloadKey>;
	public final encodedIv:String;
	public final encodedPayload:Null<String>;

	public function toXml():Stanza {
		final el = new Stanza("encrypted", { xmlns: "eu.siacs.conversations.axolotl" });
		el.tag("header", { sid: Std.string(sid) });
		for (key in keys) {
			if(key.prekey) {
				el.textTag("key", key.encodedKey, { rid: Std.string(key.rid), prekey: "true" });
			} else {
				el.textTag("key", key.encodedKey, { rid: Std.string(key.rid) });
			}
		}
		el.textTag("iv", encodedIv);
		el.up();
		el.textTag("payload", encodedPayload);
		return el;
	}

	public static function fromXml(tag:Stanza):Null<OMEMOPayload> {
		final header = tag.getChild("header");
		final sid = header.attr.get("sid");
		final encodedIv = header.getChildText("iv");
		final encodedPayload = tag.getChildText("payload");
		final keys:Array<OMEMOPayloadKey> = [
			for(key in header.allTags("key")) {
				{
					rid: Std.parseInt(key.attr.get("rid")),
					prekey: Stanza.parseXmlBool(key.attr.get("prekey")),
					encodedKey: key.getText(),
				}
			}
		];
		return {
			sid: Std.parseInt(sid),
			keys: keys,
			encodedIv: encodedIv,
			encodedPayload: encodedPayload,
		};
	}

	public static function fromMessageStanza(message:Stanza):Null<OMEMOPayload> {
		final encrypted = message.getChild("encrypted", "eu.siacs.conversations.axolotl");
		if(encrypted == null) {
			return null;
		}
		return fromXml(encrypted);
	}
	
	public function getRawIv():BytesData {
		return Base64.decode(encodedIv).getData();
	}

	public function getRawPayload():Null<BytesData> {
		if(encodedPayload == null) {
			return null;
		}
		return Base64.decode(encodedPayload).getData();
	}

	public function findKey(deviceId:Int):Null<OMEMOPayloadKey> {
		for(key in keys) {
			if(key.rid == deviceId) {
				return key;
			}
		}
		trace("OMEMO: Key missing in OMEMO header of "+keys.length+" keys. Looked for "+deviceId+" in "+([for (key in keys) key.rid].join(", ")));
		return null; // Key not found
	}
}

// The result of the OMEMO encryption step
// Combine with recipient sessions to produce an OMEMOPayload
class OMEMOEncryptionResult {
	public var iv:BytesData;
	public var key:BytesData;
	public var ciphertext:BytesData;
	public var tag:BytesData;

	public function new() {}

	private var keyWithTag:BytesData = null;
	public function getKeyWithTag():BytesData {
		if(keyWithTag != null) {
			return keyWithTag;
		}
		final keyBytes = Bytes.ofData(key);
		final tagBytes = Bytes.ofData(tag);
		final buffer = Bytes.alloc(keyBytes.length + tagBytes.length);
		buffer.blit(0, keyBytes, 0, keyBytes.length);
		buffer.blit(keyBytes.length, tagBytes, 0, tagBytes.length);
		keyWithTag = buffer.getData();
		return keyWithTag;
	}
}

class OMEMODecryptionResult {
	public final stanza:Stanza;
	public final encryptionInfo:EncryptionInfo;

	public function new(stanza:Stanza, encryptionInfo:EncryptionInfo) {
		this.stanza = stanza;
		this.encryptionInfo = encryptionInfo;
	}
}

class OMEMOSessionMetadata {
	// True when we have successfully received and decrypted any
	// non-prekey message from this session
	public final receivedSessionMessageOk:Bool;
	// True if the last message we received from this session
	// was successfully decrypted
	public final lastMessageDecryptedOk:Bool;
	// True if we have sent a key exchange to repair this session
	public final sentKeyExchange:Bool;

	public function new(receivedSessionMessageOk:Bool, lastMessageDecryptedOk:Bool, sentKeyExchange:Bool) {
		this.receivedSessionMessageOk = receivedSessionMessageOk;
		this.lastMessageDecryptedOk = lastMessageDecryptedOk;
		this.sentKeyExchange = sentKeyExchange;
	}
}

//@:nullSafety(Strict)
class OMEMO {
	private final client: Client;
	private final persistence: Persistence;
	private final signalStore: OMEMOStore;

	// Track the status of our bundle state locally
	private final bundleLocalState:FSM;

	// Track the status of our account's PEP node
	private final bundlePublicState:FSM;

	private var bundle: OMEMOBundle;

	// An array of all our device IDs on our account
	public var deviceList:Array<Int>;

	#if js
	// Constant used by JS's subtle encrypt/decrypt routines
	private final keyAlgorithm = {
		name: "AES-GCM",
		length: 128,
	};
	private final keyPurposeDecrypt = ["decrypt"];
	private final keyPurposeEncrypt = ["encrypt"];
	private final keyPurposeBoth = ["encrypt", "decrypt"];
	#end

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
		signalStore = new OMEMOStore(client.accountId(), persistence);

		 bundleLocalState = new FSM({
			transitions: [
				{ name: "loaded", from: ["loading"], to: "ok" },
				{ name: "missing", from: ["loading"], to: "creating" },
				{ name: "created", from: ["creating"], to: "ok" },
			],
			state_handlers: [
				"loading" => loadBundle,
				"creating" => createLocalBundle,
				"ok" => onLocalBundleReady,
			],
			transition_handlers: [
			],
		}, "loading");

		 bundlePublicState = new FSM({
			transitions: [
				{ name: "verify", from: ["unverified", "ok"], to: "verifying" },
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
			// If we're not already busy, verify our published
			// bundle after starting a new session (since we 
			// may have missed notifications about it changing)
			if(bundlePublicState.can("verify")) {
				bundlePublicState.event("verify");
			}
			return EventHandled;
		});
	}

	private function onLocalBundleReady(event) {
		if(bundlePublicState.getCurrentState() == "unverified") {
			bundlePublicState.event("verify");
		}
	}

	private function loadBundle(event) {
		var bundleSignedPreKey:OMEMOBundleSignedPreKey;
		var newBundle = {
			identity_key: null,
			device_id: null,
			prekeys: null,
			signed_prekey: null,
		};

		final pDeviceId = persistence.getOmemoId(client.accountId()).then(function (storedDeviceId) {
			if(storedDeviceId == null) {
				// We don't have an OMEMO identity, so we need
				// to create all our state and publish it
				return false;
			}
			trace("Using existing OMEMO identity");
			newBundle.device_id = storedDeviceId;
			return true;
		});

		final pIdentityKey = persistence.getOmemoIdentityKey(client.accountId()).then(function (storedIdentityKey) {
			if(storedIdentityKey == null) {
				trace("No identity key stored");
				this.bundleLocalState.event("missing");
				return false;
			}
			trace("Loaded identity key");
			newBundle.identity_key = Base64.encode(Bytes.ofData(storedIdentityKey.pubKey));
			return true;
		});

		final pSignedPreKey = persistence.getOmemoSignedPreKey(client.accountId(), 0).then(function (signedPreKey) {
			if(signedPreKey == null) {
				trace("No signed prekey stored");
				return false;
			}
			trace("Loaded signed prekey");
			newBundle.signed_prekey = OMEMOBundleSignedPreKey.fromSignedPreKeyPair(signedPreKey);
			return true;
		});

		final pPreKeys = persistence.getOmemoPreKeys(client.accountId()).then(function (prekeys) {
			// Always an array (just empty if no keys)
			newBundle.prekeys = [
				for(i in 0...prekeys.length) {
					{
						keyId: prekeys[i].keyId,
						pubKey: Base64.encode(Bytes.ofData(prekeys[i].keyPair.pubKey)),
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
		if(bundleLocalState.getCurrentState() == "ok") {
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
			if(devices != null) {
				this.deviceList = devices;
			}
			if(devices != null && devices.contains(this.bundle.device_id)) {
				bundlePublicState.event("verified");
			} else {
				bundlePublicState.event("needs-update");
			}
		});
		client.sendQuery(deviceListGet);
	}

	private function updatePublishedBundle(event) {
		if(bundleLocalState.getCurrentState() != "ok") {
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

	private function bundleFromPubsubItems(items:Array<Stanza>, deviceId:Int):Null<OMEMOBundle> {
		if(items.length == 0) {
			trace("No items in bundle");
			return null;
		}
		var item = items[0].getChild("bundle", "eu.siacs.conversations.axolotl");
		if (item == null) {
			trace("First item did not contain valid bundle");
			return null;
		}
		return OMEMOBundle.fromXml(item, deviceId);
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
			persistence.storeChats(client.accountId(), [chat]);
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
	// This should only be called once, when setting up a
	// new client!
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
			trace("OMEMO: Built bundle");
			persistence.storeOmemoSignedPreKey(client.accountId(), signedPreKey);

			final public_signed_prekey = OMEMOBundleSignedPreKey.fromSignedPreKeyPair(signedPreKey);
			this.bundle = {
				identity_key: Base64.encode(Bytes.ofData(identityKeyPair.pubKey)),
				device_id: deviceId,
				prekeys: prekeys,
				signed_prekey: public_signed_prekey,
			};
			return true;
		});
	}

	private function storePreKeys(prekeys:Array<PreKey>):Promise<Array<PublicPreKey>> {
		for(prekey in prekeys) {
			// Store the full keypair
			persistence.storeOmemoPreKey(client.accountId(), prekey.keyId, prekey.keyPair);
		}
		return Promise.resolve([
			for(prekey in prekeys) {
				// Emit the base64 public part for the application to publish
				{
					keyId: prekey.keyId,
					pubKey: Base64.encode(Bytes.ofData(prekey.keyPair.pubKey))
				};
			}
		]);
	}

	// Generate new prekeys
	private function generatePreKeys(_:Bool):Promise<Array<PublicPreKey>> {
		final generatedPreKeys:Promise<Array<PreKey>> = PromiseTools.all([
			for(i in 1...(NUM_PREKEYS+1)) {
				trace("Generating prekey "+Std.string(i));
				KeyHelper.generatePreKey(i);
			}
		]);

		return generatedPreKeys.then(storePreKeys);
	}

	// Generate only prekeys which are "missing" (i.e. consumed)
	// Returns an array of all prekeys, which can be used to update the
	// published bundle.
	private function generateMissingPreKeys():Promise<Array<PublicPreKey>> {
		return persistence.getOmemoPreKeys(client.accountId()).then((prekeys:Array<PreKey>) -> {
			// Generate an array of all keyIds we currently have in storage
			final currentKeyIds:Array<Int> = prekeys.map(function (prekey) {
				return prekey.keyId;
			});

			currentKeyIds.sort(function (a:Int, b:Int):Int {
				if(a == b) {
					return 0;
				}
				return a < b ? -1 : 1;
			});

			final generatedKeys:Array<Promise<PreKey>> = [];
			var idx = 0;
			for(keyId in 1...(NUM_PREKEYS+1)) {
				if(currentKeyIds[idx] == keyId) {
					// Key already present
					idx++;
				} else {
					trace("Generating replacement prekey "+Std.string(keyId));
					generatedKeys.push(KeyHelper.generatePreKey(keyId));
				}
			}

			return PromiseTools.all(generatedKeys).then(storePreKeys).then((storedPreKeys) ->
				prekeys.map(preKeyToPublicPreKey).concat(storedPreKeys)
			);
		});
	}

	private function publishNewPreKeys(newPreKeys:Array<PublicPreKey>):Bool {
		this.bundle = this.bundle.withNewPreKeys(newPreKeys);
		publishBundle();
		return true;
	}

	public function getDeviceId():Promise<Int> {
		if(bundleLocalState.getCurrentState() == "ok") {
			return Promise.resolve(this.bundle.device_id);
		}

		return persistence.getOmemoId(client.accountId()).then((deviceId) -> {
			if(deviceId == null) {
				// No device ID in storage yet. We need to trigger the
				// bundle generation
				return new Promise((resolve, reject) -> {
					bundleLocalState.once("enter/ok", (event) -> {
						resolve(bundle.device_id);
						return EventHandled;
					});
					bundleLocalState.event("missing");
				});
			} else {
				return Promise.resolve(deviceId);
			}
		});
	}

	private function decryptPayload(deviceId:Int, deviceKey:OMEMOPayloadKey, fromBare:String, payload:OMEMOPayload):Promise<BytesData> {
		var cipher:SessionCipher;
		if(payload.getRawPayload() == null) {
			// Probably a key transport message, which we don't
			// currently handle.
			return Promise.reject("no-payload");
		}
		final promCipher = new Promise<SessionCipher>((resolve, reject) -> {
			if(deviceKey.prekey) {
				// Incoming message used a prekey - build a new session between
				// us and the sender
				trace("OMEMO: Received an encrypted message using a prekey. Creating session...");
				final promSession = buildSession(deviceId, fromBare, payload.sid, "prekey");
				promSession.then((session) -> {
					getSessionCipher(deviceId, fromBare, payload.sid).then((cipher) -> {
						resolve(cipher);
					});
				});
				
			} else {
				trace("OMEMO: Received message from existing session");
				getSessionCipher(deviceId, fromBare, payload.sid).then((cipher) -> {
					resolve(cipher);
				});
			}
		});

		final promRawKeyWithTag = promCipher.then((cipher) -> {
			if(deviceKey.prekey) {
				return cipher.decryptPreKeyWhisperMessage(deviceKey.getRawKey());
			} else {
				return cipher.decryptWhisperMessage(deviceKey.getRawKey());
			}
		});

		if(deviceKey.prekey) {
			promRawKeyWithTag.then((cipher) -> {
				// Now it has been used, we need to replace the prekey that
				// was used for this incoming message. libsignal has already
				// removed it from the store, so we just need to regenerate
				// any missing keys
				generateMissingPreKeys().then(publishNewPreKeys);
			});
		}

		final promPayload = promRawKeyWithTag.then((rawKeyWithTag) -> {
			return decryptPayloadWithKey(payload.getRawPayload(), rawKeyWithTag, payload.getRawIv());
		});
		return promPayload;
	}

	private function sendKeyExchange(deviceId:Int, jid:String, rid:Int) {
		trace("OMEMO: Preparing key exchange stanza...");
		final emptyPayload = Bytes.alloc(32).toString();
		final promEncryptedMessage = encryptPayloadWithNewKey(emptyPayload);

		final promHeader = new Promise<Stanza>((resolve, reject) -> {
			promEncryptedMessage.then((encryptionResult) -> {
				buildOMEMOHeader(encryptionResult, deviceId, jid, [rid]).then(resolve, reject);
			});
		});

		final promStanza = promHeader.then((header) -> {
			final newStanza = new Stanza("message", { type: "chat" });
			header.removeChildren("payload");
			newStanza.addChild(header);
			newStanza.tag("store", { xmlns: "urn:xmpp:hints" }).up();
			return newStanza;
		});

		return promStanza.then((stanza) -> {
			trace("OMEMO: Sending key exchange stanza...");
			client.sendStanza(stanza);
			return stanza;
		});
	}

	public function decryptMessage(stanza: Stanza, fwd: Null<Stanza>):Promise<OMEMODecryptionResult> {
		// Check for carbon-forwarded message
		final from = stanza.attr.get("from") == null ? null : JID.parse(stanza.attr.get("from")).asBare();
		final header = OMEMOPayload.fromMessageStanza(fwd??stanza);
		final senderAddress = new SignalProtocolAddress(from.asString(), header.sid);
		final sessionMeta = persistence.getOmemoMetadata(client.accountId(), senderAddress.toString());
		final promDeviceId = client.omemo.getDeviceId();
		var deviceKey:Null<OMEMOPayloadKey>;
		final promResult = promDeviceId.then((deviceId:Int) -> {
			if(deviceId == header.sid) {
				// Message was sent by us (it was probably fetched from MAM)
				// We're not going to build a session with ourself (that won't
				// work!). We either have the original message locally, or we
				// don't, but we can't decrypt this copy.
				return Promise.resolve(
					new OMEMODecryptionResult(
						stanza,
						new EncryptionInfo(
							DecryptionFailure,
							NS.OMEMO,
							"own-message",
							"Past message sent from this device (cannot be decrypted)"
						)
					)
				);
			}
			deviceKey = header.findKey(deviceId);
			if(deviceKey == null) {
				trace("OMEMO: Message not encrypted for our device (looked for "+deviceId+")");
				(fwd??stanza).removeChildren("encrypted", NS.OMEMO);
				return Promise.resolve(
					new OMEMODecryptionResult(
						stanza,
						new EncryptionInfo(
							DecryptionFailure,
							NS.OMEMO,
							"missing-key",
							"Sender did not include this device in recipients"
						)
					)
				);
			}
			// FIXME: Identify correct JID for group chats
			trace("OMEMO: Decrypting payload...");
			final promPayload = decryptPayload(deviceId, deviceKey, from.asString(), header);
			return promPayload.then((decryptedPayload:BytesData) -> {
				if(decryptedPayload == null) {
					trace("OMEMO: Decrypted payload is null?");
					return Promise.resolve(new OMEMODecryptionResult(
						stanza,
						new EncryptionInfo(
							DecryptionFailure,
							NS.OMEMO,
							"invalid-payload",
							"The encrypted message was malformed"
						)
					));
				}

				(fwd??stanza).removeChildren("body");
				// FIXME: Verify valid UTF-8, etc.
				(fwd??stanza).textTag("body", Bytes.ofData(decryptedPayload).toString());
				trace("OMEMO: Payload decrypted OK!");
				return Promise.resolve(new OMEMODecryptionResult(
					stanza,
					new EncryptionInfo(
						DecryptionSuccess,
						NS.OMEMO,
					)
				));
			}, (err:Any) -> {
				trace("OMEMO: Failed to decrypt message: " + err);
				return Promise.resolve(new OMEMODecryptionResult(
					stanza,
					new EncryptionInfo(
						DecryptionFailure,
						NS.OMEMO,
						"generic",
						err,
					)
				));
			});
		});

		// Some post-decryption tasks, such as updating the session metadata
		// and sending a key exchange if necessary
		promResult.then((decryptionResult) -> {
			sessionMeta.then((metadata) -> {
				promDeviceId.then((deviceId) -> {
					if(metadata == null) {
						// No metadata in storage, so create a default
						metadata = new OMEMOSessionMetadata(false, false, false);
					}
					final decryptedOk = decryptionResult.encryptionInfo.status == DecryptionSuccess;
					var needUpdate = metadata.lastMessageDecryptedOk != decryptedOk;
					final receivedSessionMessage = deviceKey != null && !deviceKey.prekey;
					needUpdate = needUpdate || receivedSessionMessage != metadata.receivedSessionMessageOk;
					// Send a key exchange if decryption failed, this wasn't a prekey message, and
					// if we haven't already sent a key exchange
					final shouldSendKeyExchange = !decryptedOk && receivedSessionMessage && !metadata.sentKeyExchange;
					if(shouldSendKeyExchange) {
						needUpdate = true;
						trace("OMEMO: Possible broken session with <"+senderAddress.toString()+">, sending key exchange...");
						buildSession(deviceId, from.asString(), header.sid, "replacement").then((session) -> {
							sendKeyExchange(deviceId, from.asString(), header.sid);
						});
					}
					if(needUpdate) {
						persistence.storeOmemoMetadata(client.accountId(), senderAddress.toString(), new OMEMOSessionMetadata(receivedSessionMessage||metadata.receivedSessionMessageOk, decryptedOk, shouldSendKeyExchange));
					}
				});
			});
		});

		return promResult;
	}

	private function decryptPayloadWithKey(rawPayload:BytesData, rawKeyWithTag:BytesData, rawIv:BytesData):Promise<BytesData> {
		trace("OMEMO: Decrypting payload with key...");
		#if js
		// 16-byte key followed by 16-byte tag
		final bRawKeyWithTag = Bytes.ofData(rawKeyWithTag);
		final rawKey = bRawKeyWithTag.sub(0, 16).getData();
		// Produce new buffer with payload, followed by appended tag
		final payloadWithTag = Bytes.alloc(rawPayload.byteLength + 16);
		payloadWithTag.blit(0, Bytes.ofData(rawPayload), 0, rawPayload.byteLength);
		payloadWithTag.blit(rawPayload.byteLength, bRawKeyWithTag, 16, 16);
		final subtle = Browser.window.crypto.subtle;

		// We have to wrap subtle's js.lib.Promise in a thenshim Promise *shrug*
		return new Promise((resolve, reject) -> {
			subtle.importKey("raw", rawKey, keyAlgorithm, false, keyPurposeDecrypt).then((key) -> {
				subtle.decrypt({
					name: "AES-GCM",
					iv: rawIv,
				}, key, payloadWithTag.getData()).then(resolve, reject);
			});
		});
		#else
		throw new haxe.exceptions.NotImplementedException();
		#end
	}

	private function encryptPayloadWithNewKey(plaintext:String):Promise<OMEMOEncryptionResult> {
		#if js
		final subtle = Browser.window.crypto.subtle;
		final encryptedPayload = new OMEMOEncryptionResult();
		return new Promise((resolve, reject) -> {
			encryptedPayload.iv = Browser.window.crypto.getRandomValues(new js.lib.Uint8Array(12)).buffer;

			subtle.generateKey(keyAlgorithm, true, keyPurposeEncrypt).then((generatedKey) -> {
				subtle.encrypt({
					name: "AES-GCM",
					iv: encryptedPayload.iv,
				}, generatedKey, Bytes.ofString(plaintext).getData()).then((encryptionResult:BytesData) -> {
					// Process result of encryption
					final encryptedBytes = Bytes.ofData(encryptionResult);
					final ciphertextLength = encryptionResult.byteLength - 16; // Exclude GCM tag
					encryptedPayload.ciphertext = encryptedBytes.sub(0, ciphertextLength).getData();
					encryptedPayload.tag = encryptedBytes.sub(ciphertextLength, 16).getData();
					// Get the raw key data for the payload
					new Promise((resolveKey, rejectKey) -> {
						subtle.exportKey("raw", generatedKey).then(resolveKey, rejectKey);
					}).then((exportedKey:BytesData) -> {
						encryptedPayload.key = exportedKey;
						resolve(encryptedPayload);
					});
				});
			});	
		});
		#else
		throw new haxe.exceptions.NotImplementedException();
		#end
	}

	private function getContactBundle(jid:String, deviceId:Int):Promise<OMEMOBundle> {
		final node = "eu.siacs.conversations.axolotl.bundles:"+Std.string(deviceId);
		final query = new PubsubGet(jid, node);
		return new Promise<OMEMOBundle>((resolve, reject) -> {
			query.onFinished(() -> {
				resolve(bundleFromPubsubItems(query.getResult(), deviceId));
			});
			client.sendQuery(query);
		});
	}

	private function getContactDevices(jid:JID):Promise<Array<Int>> {
		final jidBareStr = jid.asBare().asString();
		return new Promise((resolve, reject) -> {
			// FIXME: Use local storage
			var chat = client.getDirectChat(jidBareStr, false);
			if(chat.omemoContactDeviceIDs != null) {
				resolve(chat.omemoContactDeviceIDs);
				return;
			}
			final deviceListGet = new PubsubGet(jidBareStr, "eu.siacs.conversations.axolotl.devicelist");
			deviceListGet.onFinished(() -> {
				final devices = deviceIdsFromPubsubItems(deviceListGet.getResult());
				if(devices != null) {
					chat.omemoContactDeviceIDs = devices;
					resolve(devices);
				} else {
					chat.omemoContactDeviceIDs = [];
					reject("no-devices");
				}
			});
			client.sendQuery(deviceListGet);
		});
	}

	private function getOwnDevices():Promise<Array<Int>> {
		return new Promise((resolve, reject) -> {
			if(this.deviceList != null) {
				resolve(this.deviceList);
			} else {
				trace("OMEMO: We don't have deviceList initialized yet, waiting for bundle ("+bundleLocalState.getCurrentState()+")");
				bundleLocalState.once("enter/ok", function (event) {
					resolve(this.deviceList);
					return EventHandled;
				});
			}
		});
	}

	public function encryptMessage(recipient:JID, stanza:Stanza):Promise<Stanza> {
		final promEncryptedMessage = encryptPayloadWithNewKey(stanza.getChildText("body"));

		final promDeviceId = this.getDeviceId();

		final promRecipientDevices = getContactDevices(recipient);

		final promHeader = new Promise<Stanza>((resolve, reject) -> {
			promDeviceId.then((deviceId) -> {
				promRecipientDevices.then((recipientDevices) -> {
					if(recipientDevices.length == 0) {
						reject("no-devices");
						return;
					}
					promEncryptedMessage.then((encryptionResult) -> {
						trace("OMEMO: Encrypting for recipient devices: " + recipientDevices.toString());
						buildOMEMOHeader(encryptionResult, deviceId, recipient.asString(), recipientDevices).then(resolve, reject);
					}, reject);
				}, reject);
			}, reject);
		});

		final promStanza = promHeader.then((header) -> {
			final newStanza = stanza.clone();
			newStanza.removeChildren("body");
			newStanza.addChild(header);
			newStanza.textTag("encryption", "", { xmlns: "urn:xmpp:eme:0", namespace: "eu.siacs.conversations.axolotl" });
			newStanza.textTag("body", "I sent you an OMEMO encrypted message but your client doesn’t seem to support that. Find more information on https://conversations.im/omemo");
			return newStanza;
		}, (failureReason) -> {
			final noRecipientSupport = failureReason == "no-devices";
			var allowUnencrypted:Bool = client.encryptionPolicy.allowUnencryptedOutgoing;

			var errMsg:String;
			if(noRecipientSupport) {
				errMsg = "Encryption failed because no recipient devices could be found";
			} else {
				errMsg = "Encryption failed due to internal error: " + failureReason;
				// Since this failure is not expected, we'll only allow the stanza
				// through if the policy does not prefer encrypted communications. If
				// encrypted communication *is* preferred, we need a good excuse to
				// send unencrypted (such as no recipient support), but no such excuse
				// is found here.
				allowUnencrypted = allowUnencrypted && !client.encryptionPolicy.preferEncryptedOutgoing;
			}

			if(!allowUnencrypted) {
				// Policy forbids outgoing unencrypted messages or some unexpected
				// error occurred (the latter is not a reason to override preferences)
				// FIXME: We need to report this to the UI somehow
				throw "Unable to send message: " + errMsg;
			}

			trace("OMEMO: Skipping encryption (permitted by policy): " + errMsg);

			// Encryption failed, but policy says this is ok.
			// Just pass through the original stanza to be sent.
			return stanza;
		});

		return promStanza;
	}

	private function buildSession(sid:Int, jid:String, rid:Int, reason:String):Promise<SignalSession> {
		final address = new SignalProtocolAddress(jid, rid);
		final promBundle = getContactBundle(jid, rid);
		trace("OMEMO: Building session for <"+address.toString()+"> for "+reason+" (fetching bundle)...");
		final promSession = promBundle.then((bundle:OMEMOBundle) -> {
			trace("OMEMO: Fetched bundle");
			final contactPreKey = bundle.getRandomPreKey();
			return new SessionBuilder(signalStore, address).processPreKey({
				registrationId: sid,
				identityKey: Base64.decode(bundle.identity_key).getData(),
				signedPreKey: {
					keyId: bundle.signed_prekey.id,
					publicKey: Base64.decode(bundle.signed_prekey.public_key).getData(),
					signature: Base64.decode(bundle.signed_prekey.signature).getData(),
				},
				preKey: {
					keyId: contactPreKey.keyId,
					publicKey: Base64.decode(contactPreKey.pubKey).getData(),
				},
			});
		}).then((_) -> {
			trace("OMEMO: Built session! ("+address.toString()+" for "+reason+")");
			return signalStore.loadSession(address);
		}, (err:Any) -> {
			trace("OMEMO: Failed to build "+reason+" session for <"+address.toString()+">: "+err);
			return signalStore.loadSession(address);
		});

		return promSession;
	}

	private function getSessionCipher(sid:Int, jid:String, rid:Int):Promise<SessionCipher> {
		final address = new SignalProtocolAddress(jid, rid);
		final promSession = signalStore.loadSession(address);

		// Load or start a session
		final promReadySession = promSession.then((session) -> {
			if(session == null) {
				trace("OMEMO: No session for "+address.toString());
				return buildSession(sid, jid, rid, "new");
			}
			return session;
		});

		final promCipher = promReadySession.then((session) -> {
			return new SessionCipher(signalStore, address);
		});

		return promCipher;
	}

	private function getRecipientSessions(sid:Int, jid:String, deviceList:Array<Int>):Promise<Array<SessionCipher>> {
		return PromiseTools.all([
			for (rid in deviceList) {
				getSessionCipher(sid, jid, rid);
			}
		]);
	}

	private function encryptPayloadKeyForSession(encryptionResult:OMEMOEncryptionResult, sessionCipher:SessionCipher):Promise<SignalCipherText> {
		final keyWithTag = encryptionResult.getKeyWithTag();
		return sessionCipher.encrypt(keyWithTag);
	}

	// Convert a key from a string of raw bytes to base64
	private static function b64EncodeKey(keyStr:String) {
		#if js
			// Haxe cannot natively convert this string to a byte array. It only supports two
			// encodings - 'UTF8' and 'RawNative'. The former wrongly tries to interpret
			// the binary data as UTF-8 sequences, and the latter translates each character
			// to a pair of bytes (since JS uses UTF-16).
			return Browser.window.btoa(keyStr);
		#else
			return Base64.encode(Bytes.ofString(keyStr, RawNative));
		#end
	}

	private function encryptForDevice(sid:Int, jid:String, rid:Int, encryptionResult:OMEMOEncryptionResult):Promise<OMEMOPayloadKey> {
		final promSessionCipher = getSessionCipher(sid, jid, rid);
		return promSessionCipher.then((sessionCipher) -> {
			return encryptPayloadKeyForSession(encryptionResult, sessionCipher).then((encryptedKey) -> {
				final payloadKey:OMEMOPayloadKey = {
					rid: rid,
					prekey: encryptedKey.type == 3,
					encodedKey: b64EncodeKey(encryptedKey.body),
				};
				return payloadKey;
			});
		});
	}

	private function buildOMEMOHeader(encryptionResult:OMEMOEncryptionResult, sid:Int, jid:String, deviceList:Array<Int>):Promise<Stanza> {
		// We'll include keys for our contact's devices, but we also need
		// to include any of our own devices, so they can read the outgoing
		// message
		final promKeys = getOwnDevices().then((ownDeviceList) -> {
			trace("OMEMO: Have contact and own device lists");
			final keys = [];
			for(rid in ownDeviceList) {
				// Don't encrypt to our own device (we already have the original message locally)
				if(sid != rid) {
					keys.push(encryptForDevice(sid, this.client.accountId(), rid, encryptionResult));
				}
			}

			for(rid in deviceList) {
				keys.push(encryptForDevice(sid, jid, rid, encryptionResult));
			}

			// Return an array of promises which each resolve to an OMEMOPayloadKey
			return keys;
		});

		final promHeader = new Promise((resolve, reject) -> {
			promKeys.then((keys) -> {
				PromiseTools.all(keys).then((recipientKeys) -> {
					trace("OMEMO: Generating OMEMO header");
					final header:OMEMOPayload = {
						sid: sid,
						keys: recipientKeys,
						encodedIv: Base64.encode(Bytes.ofData(encryptionResult.iv)),
						encodedPayload: Base64.encode(Bytes.ofData(encryptionResult.ciphertext)),
					};
					resolve(header);
				});
			});
		});

		return promHeader.then((header) -> {
			return header.toXml();
		});
	}

	static private function preKeyToPublicPreKey(prekey:PreKey):PublicPreKey {
		return {
			keyId: prekey.keyId,
			pubKey: Base64.encode(Bytes.ofData(prekey.keyPair.pubKey)),
		};
	}
}
