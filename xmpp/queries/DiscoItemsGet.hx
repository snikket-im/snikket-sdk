package xmpp.queries;

import haxe.DynamicAccess;
import haxe.Exception;

import xmpp.ID;
import xmpp.JID;
import xmpp.ResultSet;
import xmpp.Stanza;
import xmpp.Stream;
import xmpp.queries.GenericQuery;

class DiscoItemsGet extends GenericQuery {
	public var xmlns(default, null) = "http://jabber.org/protocol/disco#items";
	public var queryId:String = null;
	public var responseStanza(default, null):Stanza;
	private var result: Array<{ jid: JID, name: Null<String>, node: Null<String> }>;

	public function new(to: String, ?node: String) {
		var attr: DynamicAccess<String> = { xmlns: xmlns };
		if (node != null) attr["node"] = node;
		/* Build basic query */
		queryId = ID.short();
		queryStanza = new Stanza(
			"iq",
			{ to: to, type: "get", id: queryId }
		).tag("query", attr).up();
	}

	public function handleResponse(stanza:Stanza) {
		responseStanza = stanza;
		finish();
	}

	public function getResult() {
		if (responseStanza == null) {
			return null;
		}
		if(result == null) {
			final q = responseStanza.getChild("query", xmlns);
			if(q == null) {
				return null;
			}
			result = [];
			for (item in q.allTags("item")) {
				final jid = item.attr.get("jid");
				if (jid != null) {
					result.push({jid: JID.parse(jid), name: item.attr.get("name"), node: item.attr.get("node")});
				}
			}
		}
		return result;
	}
}
