package borogove.queries;

import haxe.DynamicAccess;
import haxe.Exception;

import borogove.ID;
import borogove.ResultSet;
import borogove.Stanza;
import borogove.Stream;
import borogove.queries.GenericQuery;
import borogove.Caps;

class DiscoInfoGet extends GenericQuery {
	public var xmlns(default, null) = "http://jabber.org/protocol/disco#info";
	public var queryId:String = null;
	public var ver:String = null;
	public var responseStanza(default, null):Stanza;
	private var result: Caps;

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
			final identities = q.allTags("identity");
			final features = q.allTags("feature");
			result = new Caps(
				q.attr.get("node"),
				identities.map((identity) -> new Identity(identity.attr.get("category"), identity.attr.get("type"), identity.attr.get("name"))),
				features.map((feature) -> feature.attr.get("var"))
			);
		}
		return result;
	}
}
