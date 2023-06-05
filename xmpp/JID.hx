package xmpp;

typedef SplitJID = {
	var ?node : String;
	var domain : String;
	var ?resource : String;
};

class JID {
	public static function split(jid:String):SplitJID {
		var resourceDelimiter = jid.indexOf("/");
		var nodeDelimiter = jid.indexOf("@");
		if(nodeDelimiter >= resourceDelimiter) {
			nodeDelimiter = -1;
		}
		return {
			node: (nodeDelimiter>0)?jid.substr(0, nodeDelimiter):null,
			domain: jid.substring((nodeDelimiter == -1)?0:nodeDelimiter+1, (resourceDelimiter == -1)?jid.length+1:resourceDelimiter),
			resource: (resourceDelimiter == -1)?null:jid.substring(resourceDelimiter+1),
		};
	}
}
