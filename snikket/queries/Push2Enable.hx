package snikket.queries;

import haxe.io.Bytes;
import haxe.crypto.Base64;

import snikket.ID;
import snikket.Stanza;
import snikket.queries.GenericQuery;

class Push2Enable extends GenericQuery {
	public var xmlns(default, null) = "urn:xmpp:push2:0";
	public var queryId:String = null;
	public var ver:String = null;
	private var responseStanza:Stanza;

	public function new(to: String, service: String, client: String, ua_public: Bytes, auth_secret: Bytes, jwt_alg: Null<String>, jwt_key: Bytes, jwt_claims: Map<String, String>, chats: Array<{ jid: String, mention: Bool, reply: Bool }>) {
		queryId = ID.short();
		queryStanza = new Stanza(
			"iq",
			{ to: to, type: "set", id: queryId }
		);
		final enable = queryStanza.tag("enable", { xmlns: xmlns });
		enable.textTag("service", service);
		enable.textTag("client", client);
		final match = enable.tag("match", { profile: "urn:xmpp:push2:match:important" });
		for (chat in chats) {
			final chatel = match.tag("chat", { jid: chat.jid });
			if (chat.mention) chatel.tag("mention").up();
			if (chat.reply) chatel.tag("reply").up();
			chatel.up();
		}
		final send = match.tag("send", { xmlns: "urn:xmpp:push2:send:sce+rfc8291+rfc8292:0" });
		send.textTag("ua-public", Base64.encode(ua_public));
		send.textTag("auth-secret", Base64.encode(auth_secret));
		if (jwt_alg != null) {
			send.textTag("jwt-alg", jwt_alg);
			send.textTag("jwt-key", Base64.encode(jwt_key));
			for (key => value in jwt_claims) {
				send.textTag("jwt-claim", value, { name: key });
			}
		}
		enable.up().up().up();
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
