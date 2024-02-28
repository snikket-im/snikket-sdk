package xmpp;

class PubsubEvent {
	private var from:Null<String>;
	private var to:Null<String>;
	private var node:String;
	private var items:Array<Stanza>;

	public function new(from:Null<String>, to:Null<String>, node:String, items:Array<Stanza>) {
		this.from = from;
		this.to = to;
		this.node = node;
		this.items = items;
	}

	public static function fromStanza(stanza:Stanza):Null<PubsubEvent> {
		var event = stanza.getChild("event", "http://jabber.org/protocol/pubsub#event");
		if (event == null) return null;

		var items = event.getChild("items"); // xmlns is same as event tag
		if (items == null) return null;

		// item tag is same xmlns as event and items tag
		return new PubsubEvent(stanza.attr.get("from"), stanza.attr.get("to"), items.attr.get("node"), items.allTags("item"));
	}

	public function getFrom():Null<String> {
		return this.from;
	}

	public function getNode():String {
		return this.node;
	}

	public function getItems():Array<Stanza> {
		return this.items;
	}
}
