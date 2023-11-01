package xmpp;

@:expose
class Presence {
	public var caps:Null<Caps>;

	public function new(caps: Null<Caps>) {
		this.caps = caps;
	}
}
