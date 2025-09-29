package borogove;

@:expose
class JID {
	public final node : Null<String>;
	public final domain : String;
	public final resource : Null<String>;

	public function new(?node:String, domain:String, ?resource:String, ?raw = false) {
		this.node = node == null || raw == true ? node :
			StringTools.replace(StringTools.replace(StringTools.replace(
			StringTools.replace(StringTools.replace(StringTools.replace(
			StringTools.replace(StringTools.replace(StringTools.replace(
			StringTools.replace(StringTools.replace(StringTools.replace(
			StringTools.replace(StringTools.replace(StringTools.replace(
			StringTools.replace(StringTools.replace(StringTools.replace(
				StringTools.replace(StringTools.trim(node),
				"\\5c", "\\5c5c"),
				"\\20", "\\5c20"),
				"\\22", "\\5c22"),
				"\\26", "\\5c26"),
				"\\27", "\\5c27"),
				"\\2f", "\\5c2f"),
				"\\3a", "\\5c3a"),
				"\\3c", "\\5c3c"),
				"\\3e", "\\5c3e"),
				"\\40", "\\5c40"),
				" ", "\\20"),
				'"', "\\22"),
				"&", "\\26"),
				"'", "\\27"),
				"/", "\\2f"),
				":", "\\3a"),
				"<", "\\3c"),
				">", "\\3e"),
				"@", "\\40");
		this.domain = domain;
		this.resource = resource;
	}

	public static function parse(jid:String):JID {
		var resourceDelimiter = jid.indexOf("/");
		var nodeDelimiter = jid.indexOf("@");
		if(resourceDelimiter > 0 && nodeDelimiter >= resourceDelimiter) {
			nodeDelimiter = -1;
		}
		return new JID(
			(nodeDelimiter>0)?jid.substr(0, nodeDelimiter):null,
			jid.substring((nodeDelimiter == -1)?0:nodeDelimiter+1, (resourceDelimiter == -1)?jid.length+1:resourceDelimiter),
			(resourceDelimiter == -1)?null:jid.substring(resourceDelimiter+1),
			true
		);
	}

	public function asBare():JID {
		return new JID(this.node, this.domain, null, true);
	}

	public function withResource(resource: String): JID {
		return new JID(this.node, this.domain, resource, true);
	}

	public function isValid():Bool {
		return domain.indexOf(".") >= 0;
	}

	public function isDomain():Bool {
		return node == null;
	}

	public function isBare():Bool {
		return resource == null;
	}

	public function equals(rhs:JID):Bool {
		return (
			this.node == rhs.node &&
			this.domain == rhs.domain &&
			this.resource == rhs.resource
		);
	}

	public function asString():String {
		return (
			(this.node != null ? this.node + "@" : "") +
			this.domain +
			(this.resource != null ? "/" + this.resource : "")
		);
	}
}
