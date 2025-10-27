package borogove;

import borogove.Hash;

@:expose
class Presence {
	public var caps:Null<Caps>;
	public final mucUser:Null<Stanza>;
	public final avatarHash:Null<Hash>;

	public function new(caps: Null<Caps>, mucUser: Null<Stanza>, avatarHash: Null<Hash>) {
		this.caps = caps;
		this.mucUser = mucUser;
		this.avatarHash = avatarHash;
	}
}
