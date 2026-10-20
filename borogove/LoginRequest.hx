package borogove;

@:nullSafety(Strict)
@:expose
class LoginRequest {
	@:allow(borogove)
	private final from: JID;
	@:allow(borogove)
	private final threadId: String;
	public final id: String;
	public final method: String;
	public final url: String;
	public final timeSent: String;

	@:allow(borogove)
	private function new(from: JID, threadId: String, id: String, method: String, url: String, timeSent: String) {
		this.from = from;
		this.threadId = threadId;
		this.id = id;
		this.method = method;
		this.url = url;
		this.timeSent = timeSent;
	}

	@:allow(borogove)
	private function approveStanza() {
		return new Stanza("message", { to: from.asString() })
			.textTag("thread", threadId)
			.tag("confirm", {
				xmlns: "http://jabber.org/protocol/http-auth",
				id: id,
				method: method,
				url: url
			}).up();
	}

	@:allow(borogove)
	private function rejectStanza(reason: String) {
		return new Stanza("message", { to: from.asString(), type: "error" })
			.textTag("thread", threadId)
			.tag("confirm", {
				xmlns: "http://jabber.org/protocol/http-auth",
				id: id,
				method: method,
				url: url
			}).up()
			.tag("error", { code: "401", type: "auth" })
				.tag("not-authorized", { xmlns: "urn:ietf:params:xml:ns:xmpp-stanzas" }).up()
				.textTag("text", reason, { xmlns: "urn:ietf:params:xml:ns:xmpp-stanzas" })
				.up();
	}
}
