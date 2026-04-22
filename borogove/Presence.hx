package borogove;

import borogove.MucUser;
import borogove.Hash;

@:nullSafety(StrictThreaded)
@:forward(toString)
@:expose
abstract Presence(Stanza) from Stanza to Stanza {
	public var capsNode(get, never): Null<String>;
	public var ver(get, never): Null<String>;
	public var mucUser(get, never): Null<MucUser>;
	public var avatarHash(get, never): Null<Hash>;

	public function new(caps: Null<Caps>, mucUser: Null<MucUser>, avatarHash: Null<Hash>): Presence {
		final stanza = new Stanza("presence", { xmlns: "jabber:client" });
		if (caps != null) caps.addC(stanza);
		if (mucUser != null) stanza.addChild(mucUser);
		if (avatarHash != null) {
			stanza.tag("x", { xmlns: "vcard-temp:x:update" }).textTag("photo", avatarHash.toHex()).up();
		}

		this = stanza;
	}

	private inline function get_capsNode() {
		final c = this.getChild("c", "http://jabber.org/protocol/caps");
		return c?.attr?.get("node");
	}

	private inline function get_ver() {
		final c = this.getChild("c", "http://jabber.org/protocol/caps");
		return c?.attr?.get("ver");
	}

	private inline function get_mucUser() {
		return this.getChild("x", "http://jabber.org/protocol/muc#user");
	}

	private inline function get_avatarHash() {
		final avatarSha1Hex = this.findText("{vcard-temp:x:update}x/photo#");
		return avatarSha1Hex == null || avatarSha1Hex == "" ? null : Hash.fromHex("sha-1", avatarSha1Hex);
	}
}
