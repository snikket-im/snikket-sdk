package xmpp.queries;

import haxe.DynamicAccess;
import haxe.Exception;
import haxe.ds.Either;

import xmpp.ID;
import xmpp.ResultSet;
import xmpp.Stanza;
import xmpp.Stream;
import xmpp.queries.GenericQuery;
import xmpp.Caps;

class JabberIqGatewayGet extends GenericQuery {
	public var xmlns(default, null) = "jabber:iq:gateway";
	public var queryId:String = null;
	public var ver:String = null;
	private var responseStanza:Stanza;
	private var result:Null<Either<String, String>>;

	public function new(to: String, ?prompt: String) {
		queryId = ID.short();
		queryStanza = new Stanza(
			"iq",
			{ to: to, type: prompt == null ? "get" : "set", id: queryId }
		);
		final query = queryStanza.tag("query", { xmlns: xmlns });
		if (prompt != null) {
			query.textTag("prompt", prompt, {});
		}
		query.up();
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
			final error = responseStanza.getChild("error");
			if (error == null) {
				final q = responseStanza.getChild("query", xmlns);
				if(q == null) {
					return null;
				}
				final prompt = q.getChild("prompt");
				if (prompt == null) {
					final jid = q.getChild("jid");
					if (jid == null) return null;
					result = Right(jid.getText());
				} else {
					result = Right(prompt.getText());
				}
			} else {
				if (error.getChild("service-unavailable", "urn:ietf:params:xml:ns:xmpp-stanzas") != null) return null;
				if (error.getChild("feature-not-implemented", "urn:ietf:params:xml:ns:xmpp-stanzas") != null) return null;
				result = Left(error.getText());
			}
		}
		return result;
	}
}
