package xmpp;

class JID {
	public final node : Null<String>;
	public final domain : String;
	public final resource : Null<String>;

	public function new(?node:String, domain:String, ?resource:String) {
		this.node = node;
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
			(resourceDelimiter == -1)?null:jid.substring(resourceDelimiter+1)
		);
	}

	public function asBare():JID {
		return new JID(this.node, this.domain);
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
