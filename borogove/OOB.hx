package borogove;

@:forward(toString)
abstract OOB(Stanza) from Stanza to Stanza {
	public var desc(get, never): Null<String>;
	public var url(get, never): Null<String>;

	inline public function get_desc() {
		return this.getChildText("desc");
	}

	inline public function get_url() {
		return this.getChildText("url");
	}
}
