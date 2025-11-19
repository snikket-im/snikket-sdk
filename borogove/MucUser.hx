package borogove;

import borogove.Stanza;
import borogove.JID;

@:forward(toString)
abstract MucUser(Stanza) from Stanza to Stanza {
	public var statusCodes(get, never): Array<String>;
	public var role(get, never): String;
	public var affiliation(get, never): String;
	public var jid(get, never): Null<JID>;

	inline private function get_statusCodes() {
		return this.allTags("status").map(el -> el.attr.get("code"));
	}

	inline private function get_role() {
		return item()?.attr?.get("role") ?? "none";
	}

	inline private function get_affiliation() {
		return item()?.attr?.get("affiliation") ?? "none";
	}

	inline private function get_jid() {
		final jid = item()?.attr?.get("jid");
		if (jid == null) return null;

		return JID.parse(jid);
	}

	inline private function item() {
		return this.getChild("item");
	}
}
