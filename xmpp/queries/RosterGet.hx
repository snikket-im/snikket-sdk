package xmpp.queries;

import haxe.DynamicAccess;
import haxe.Exception;

import xmpp.ID;
import xmpp.ResultSet;
import xmpp.Stanza;
import xmpp.Stream;
import xmpp.queries.GenericQuery;

class RosterGet extends GenericQuery {
	public var xmlns(default, null) = "jabber:iq:roster";
	public var queryId:String = null;
	public var ver:String = null;
	private var responseStanza:Stanza;
	private var result: Array<{ jid: String, fn: String, subscription: String }>;

	public function new(?ver: String) {
		var attr: DynamicAccess<String> = { xmlns: xmlns };
		if (ver != null) attr["ver"] = ver;
		/* Build basic query */
		queryId = ID.short();
		queryStanza = new Stanza("iq", { type: "get" })
			.tag("query", attr)
			.up();
	}

	public function handleResponse(stanza:Stanza) {
		responseStanza = stanza;
		finish();
	}

	public function getResult() {
		if (responseStanza == null) {
			return [];
		}
		if(result == null) {
			var q = responseStanza.getChild("query", "jabber:iq:roster");
			if(q == null) {
				return [];
			}
			ver = q.attr.get("ver");
			// TODO: cannot specify namespace here due to bugs in namespace handling in allTags
			result = q.allTags("item").map((item) -> {
				jid: item.attr.get("jid"),
				fn: item.attr.get("name"),
				subscription: item.attr.get("subscription")
			});
		}
		return result;
	}
}
