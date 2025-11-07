package borogove;

import borogove.Stanza;

@:forward(toString)
abstract DataForm(Stanza) from Stanza to Stanza {
	inline public function fields(): Array<Field> {
		return this.allTags("field");
	}

	public function field(name: String): Null<Field> {
		final matches = fields().filter(f -> f.name == name);
		if (matches.length > 1) {
			trace('Multiple fields matching ${name}');
		}
		return matches[0];
	}
}

abstract Field(Stanza) from Stanza to Stanza {
	public var name(get, never): String;
	public var value(get, never): Array<String>;

	inline public function get_name() {
		return this.attr.get("var");
	}

	public function get_value() {
		return this.allTags("value").map(v -> v.getText());
	}
}
