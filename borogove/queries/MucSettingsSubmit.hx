package borogove.queries;

import borogove.ID;
import borogove.Stanza;
import borogove.Form;

class MucSettingsSubmit extends GenericQuery {
	private var responseStanza:Stanza;
	public var error(default, null):Null<String> = null;

	public function new(to: String, submitForm: Stanza) {
		queryStanza = new Stanza("iq", { type: "set", to: to, id: ID.unique() })
			.tag("query", { xmlns: "http://jabber.org/protocol/muc#owner" })
			.addChild(submitForm)
			.up();
	}

	public function handleResponse(stanza:Stanza) {
		responseStanza = stanza;
		if (stanza.attr.get("type") == "error") {
			error = stanza.getError().text ?? stanza.getError().condition ?? "error";
		}
		finish();
	}

	public function getResult(): Bool {
		if (responseStanza == null || error != null) return false;

		return true;
	}
}
