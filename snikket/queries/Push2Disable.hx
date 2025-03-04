package snikket.queries;

import haxe.io.Bytes;
import haxe.crypto.Base64;

import snikket.ID;
import snikket.Stanza;
import snikket.queries.GenericQuery;

class Push2Disable extends GenericQuery {
	public var xmlns(default, null) = "urn:xmpp:push2:0";
	public var queryId:String = null;
	public var ver:String = null;
	private var responseStanza:Stanza;

	public function new(to: String) {
		queryId = ID.short();
		queryStanza = new Stanza(
			"iq",
			{ to: to, type: "set", id: queryId }
		);
		queryStanza.tag("disable", { xmlns: xmlns });
	}

	public function handleResponse(stanza:Stanza) {
		responseStanza = stanza;
		finish();
	}

	public function getResult() {
		if (responseStanza == null) {
			return null;
		}
		return { type: responseStanza.attr.get("type") };
	}
}
