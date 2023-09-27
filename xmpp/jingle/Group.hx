package xmpp.jingle;

class Group {
	 public var semantics (default, null): String;
	 public var identificationTags (default, null): Array<String>;

	 public function new(semantics: String, identificationTags: Array<String>) {
		  this.semantics = semantics;
		  this.identificationTags = identificationTags;
	 }

	public static function parse(input: String) {
		final segments = input.split(" ");
		if (segments.length < 2) return null;
		return new Group(segments[0], segments.slice(1));
	}

	public static function fromElement(el: Stanza) {
		final idTags = [];
		for (content in el.allTags("content")) {
			if (content.attr.get("name") != null) idTags.push(content.attr.get("name"));
		}
		return new Group(el.attr.get("semantics"), idTags);
	 }

	public function toSdp() {
		if (semantics.indexOf(" ") >= 0) {
			throw "Group semantics cannot contain a space in SDP";
		}
		return semantics + " " + identificationTags.join(" ");
	}

	public function toElement() {
		final group = new Stanza("group", { xmlns: "urn:xmpp:jingle:apps:grouping:0", semantics: semantics });
		for (tag in identificationTags) {
			group.tag("content", { name: tag }).up();
		}
		return group;
	}
}
