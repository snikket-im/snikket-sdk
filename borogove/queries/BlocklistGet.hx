package borogove.queries;

import haxe.DynamicAccess;
import haxe.Exception;

import borogove.ID;
import borogove.ResultSet;
import borogove.Stanza;
import borogove.Stream;
import borogove.queries.GenericQuery;

class BlocklistGet extends GenericQuery {
	public var xmlns(default, null) = "urn:xmpp:blocking";
	public var queryId:String = null;
	public var ver:String = null;
	private var responseStanza:Stanza;
	private var result: Array<String>;

	public function new() {
		/* Build basic query */
		queryId = ID.short();
		queryStanza = new Stanza("iq", { type: "get", id: queryId })
			.tag("blocklist", { xmlns: xmlns }).up();
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
			final q = responseStanza.getChild("blocklist", xmlns);
			if(q == null) {
				return [];
			}
			// TODO: cannot specify namespace here due to bugs in namespace handling in allTags
			result = q.allTags("item").map(el -> el.attr.get("jid"));
		}
		return result;
	}
}
