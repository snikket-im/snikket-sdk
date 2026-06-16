package borogove.queries;

import borogove.ID;
import borogove.Stanza;

class MucSettingsGet extends GenericQuery {
	private var responseStanza:Stanza;
	public var error(default, null):Null<String> = null;

	public function new(to: String) {
		queryStanza = new Stanza("iq", { type: "get", to: to, id: ID.unique() })
			.tag("query", { xmlns: "http://jabber.org/protocol/muc#owner" })
			.up();
	}

	public function handleResponse(stanza:Stanza) {
		responseStanza = stanza;
		if (stanza.attr.get("type") == "error") {
			error = stanza.getError().text ?? stanza.getError().condition ?? "error";
		}
		finish();
	}

	public function getResult(): Null<DataForm> {
		if (responseStanza == null || error != null) return null;

		final query = responseStanza.getChild("query", "http://jabber.org/protocol/muc#owner");
		if (query == null) return null;

		final x = query.getChild("x", "jabber:x:data");
		if (x == null) return null;

		return x;
	}
}
