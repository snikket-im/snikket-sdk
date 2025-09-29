package borogove.queries;

import haxe.DynamicAccess;
import haxe.Exception;

import borogove.ID;
import borogove.ResultSet;
import borogove.Stanza;
import borogove.Stream;
import borogove.queries.GenericQuery;
import borogove.Caps;

class ExtDiscoGet extends GenericQuery {
	public var xmlns(default, null) = "urn:xmpp:extdisco:2";
	public var queryId:String = null;
	public var ver:String = null;
	private var responseStanza:Stanza;
	private var result: Array<Stanza>;

	public function new(to: String) {
		/* Build basic query */
		queryId = ID.short();
		queryStanza = new Stanza(
			"iq",
			{ to: to, type: "get", id: queryId }
		).tag("services", { xmlns: xmlns }).up();
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
			final q = responseStanza.getChild("services", xmlns);
			if(q == null) {
				return null;
			}
			result = q.allTags("service");
		}
		return result;
	}
}
