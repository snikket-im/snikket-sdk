package xmpp;

import xmpp.Chat;
import xmpp.EventEmitter;
import xmpp.Stream;
import xmpp.queries.GenericQuery;

typedef ChatList = Array<Chat>;

class Client extends xmpp.EventEmitter {
	private var stream:GenericStream;
	private var chatMessageHandlers: Array<(ChatMessage)->Void> = [];
	public var jid(default,null):String;

	public function new(jid: String) {
		super();
		this.jid = jid;
		stream = new Stream();
		stream.on("status/online", this.onConnected);
		stream.on("auth/password-needed", (data)->this.trigger("auth/password-needed", { jid: this.jid }));
	}

	public function start() {
		stream.connect(jid);
	}

	public function addChatMessageListener(handler:ChatMessage->Void):Void {
		chatMessageHandlers.push(handler);
	}

	private function onConnected(data) {
		this.stream.on("message", function(event) {
			final stanza:Stanza = event.stanza;
			final chatMessage = ChatMessage.fromStanza(stanza, jid);
			if (chatMessage != null) {
				for (handler in chatMessageHandlers) {
					handler(chatMessage);
				}
			}

			return EventUnhandled; // Allow others to get this event as well
		});

		stream.sendStanza(new Stanza("presence")); // Set self to online
		return this.trigger("status/online", {});
	}

	public function usePassword(password: String):Void {
		this.stream.trigger("auth/password", { password: password });
	}

	/* Return array of chats, sorted by last activity */
	public function getChats():ChatList {
		return [];
	}

	public function getDirectChat(chatId:String):DirectChat {
		return new DirectChat(this, this.stream, chatId);
	}

	/* Internal-ish methods */
	public function sendQuery(query:GenericQuery) {
		this.stream.sendIq(query.getQueryStanza(), query.handleResponse);
	}

	public function sendStanza(stanza:Stanza) {
		stream.sendStanza(stanza);
	}
}
