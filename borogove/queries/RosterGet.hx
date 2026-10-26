package borogove.queries;

import haxe.DynamicAccess;
import haxe.Exception;

import borogove.ID;
import borogove.ResultSet;
import borogove.Stanza;
import borogove.Stream;
import borogove.queries.GenericQuery;

class RosterGet extends GenericQuery {
	public var xmlns(default, null) = "jabber:iq:roster";
	public var queryId:String = null;
	public var ver:String = null;
	private var responseStanza:Stanza;
	private var result: Array<RosterItem>;

	public function new(?ver: String) {
		var attr: DynamicAccess<String> = { xmlns: xmlns };
		if (ver != null) attr["ver"] = ver;
		/* Build basic query */
		queryId = ID.unique();
		queryStanza = new Stanza("iq", { type: "get" })
			.tag("query", attr)
			.up();
	}

	public function handleResponse(stanza:Stanza) {
		responseStanza = stanza;
		finish();
	}

	/**
		Whether the response contained the full roster.

		A versioned response may contain no query at all when the cached roster
		is still current; that is different from an empty roster query.
	**/
	public function hasFullRoster():Bool {
		return responseStanza != null && responseStanza.getChild("query", xmlns) != null;
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
			result = q.allTags("item");
		}
		return result;
	}
}
