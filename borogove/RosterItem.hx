package borogove;

@:nullSafety(StrictThreaded)
@:forward(toString)
abstract RosterItem(Stanza) from Stanza to Stanza {
	public var jid(get, never): Null<String>;
	public var name(get, never): Null<String>;
	public var subscription(get, never): Null<String>;
	public var groups(get, never): Array<String>;

	private inline function get_jid() {
		return this.attr.get("jid");
	}

	private inline function get_name() {
		return this.attr.get("name");
	}

	private inline function get_subscription() {
		return this.attr.get("subscription");
	}

	private inline function get_groups() {
		// TODO: cannot specify namespace here due to bugs in namespace handling in allTags
		return this.allTags("group").map(g -> g.getText());
	}
}
