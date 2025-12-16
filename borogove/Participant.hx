package borogove;

import thenshim.Promise;

import borogove.queries.PubsubGet;

#if cpp
import HaxeCBridge;
#end

@:expose
@:nullSafety(Strict)
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Participant {
	public final displayName: String;
	public final photoUri: Null<String>;
	public final placeholderUri: String;
	public final isSelf: Bool;
	private final jid: JID;

	@:allow(borogove)
	private function new(displayName: String, photoUri: Null<String>, placeholderUri: String, isSelf: Bool, jid: JID) {
		this.displayName = displayName;
		this.photoUri = photoUri;
		this.placeholderUri = placeholderUri;
		this.isSelf = isSelf;
		this.jid = jid;
	}

	public function profile(client: Client): Promise<Profile> {
		return new Promise((resolve, reject) -> {
			final get = new PubsubGet(jid.asString(), "urn:xmpp:vcard4");
			get.onFinished(() -> {
				final item = get.getResult()[0];
				final fromItem = item?.getChild("vcard", "urn:ietf:params:xml:ns:vcard-4.0");
				final vcard = fromItem == null ? new Stanza("vcard", { xmlns: "urn:ietf:params:xml:ns:vcard-4.0" }) : fromItem;
				if (!vcard.hasChild("fn")) {
					vcard.insertChild(0, new Stanza("fn").textTag("text", displayName));
				}
				resolve(new Profile(vcard));
			});
			client.sendQuery(get);
		});
	}
}
