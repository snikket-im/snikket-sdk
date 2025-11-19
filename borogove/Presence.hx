package borogove;

import borogove.MucUser;
import borogove.Hash;

@:expose
class Presence {
	public var caps:Null<Caps>;
	public final mucUser:Null<MucUser>;
	public final avatarHash:Null<Hash>;

	public function new(caps: Null<Caps>, mucUser: Null<MucUser>, avatarHash: Null<Hash>) {
		this.caps = caps;
		this.mucUser = mucUser;
		this.avatarHash = avatarHash;
	}
}
