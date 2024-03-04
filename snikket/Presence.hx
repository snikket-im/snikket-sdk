package snikket;

@:expose
class Presence {
	public var caps:Null<Caps>;
	public var mucUser:Null<Stanza>;

	public function new(caps: Null<Caps>, mucUser: Null<Stanza>) {
		this.caps = caps;
		this.mucUser = mucUser;
	}
}
