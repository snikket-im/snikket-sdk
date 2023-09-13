package xmpp.queries;

import haxe.DynamicAccess;
import haxe.Exception;

import xmpp.ID;
import xmpp.ResultSet;
import xmpp.Stanza;
import xmpp.Stream;
import xmpp.queries.GenericQuery;

class PubsubGet extends GenericQuery {
	public var xmlns(default, null) = "http://jabber.org/protocol/pubsub";
	public var queryId:String = null;
	public var ver:String = null;
	private var responseStanza:Stanza;
	private var result: Array<Stanza>;

	public function new(to: String, node: String, ?itemId: String) {
		var attr: DynamicAccess<String> = { node: node };
		if (ver != null) attr["ver"] = ver;
		/* Build basic query */
		queryId = ID.short();
		queryStanza = new Stanza("iq", { to: to, type: "get", id: queryId });
		final items = queryStanza
			.tag("pubsub", { xmlns: xmlns })
			.tag("items", { node: node });
		if (itemId != null) {
			items.tag("item", { id: itemId }).up();
		}
		queryStanza.up().up();
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
			final q = responseStanza.getChild("pubsub", xmlns);
			if(q == null) {
				return [];
			}
			final items = q.getChild("items"); // same xmlns as pubsub
			if (items == null) {
				return [];
			}
			if (items.attr.get("xmlns") == null) items.attr.set("xmlns", xmlns);
			// TODO: cannot specify namespace here due to bugs in namespace handling in allTags
			result = items.allTags("item");
		}
		return result;
	}
}
