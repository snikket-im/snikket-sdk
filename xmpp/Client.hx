package xmpp;

import xmpp.Chat;
import xmpp.EventEmitter;
import xmpp.Stream;
import xmpp.queries.GenericQuery;
import xmpp.queries.RosterGet;

typedef ChatList = Array<Chat>;

@:expose
class Client extends xmpp.EventEmitter {
	private var stream:GenericStream;
	private var chatMessageHandlers: Array<(ChatMessage)->Void> = [];
	public var jid(default,null):String;
	private var chats: ChatList = [];

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
				var chat = getDirectChat(chatMessage.conversation());
				chatActivity(chat);
				for (handler in chatMessageHandlers) {
					handler(chatMessage);
				}
			}

			return EventUnhandled; // Allow others to get this event as well
		});

		this.stream.on("iq", function(event) {
			final stanza:Stanza = event.stanza;
			if (
				stanza.attr.get("from") != null &&
				stanza.attr.get("from") != JID.parse(jid).domain
			) {
				return EventUnhandled;
			}

			var roster = new RosterGet();
			roster.handleResponse(stanza);
			var items = roster.getResult();
			if (items.length == 0) return EventUnhandled;

			for (item in items) {
				if (item.subscription != "remove") getDirectChat(item.jid, false);
			}
			this.trigger("chats/update", chats);

			var reply = new Stanza("iq", {
				type: "result",
				id: stanza.attr.get("id"),
				to: stanza.attr.get("from")
			});
			sendStanza(reply);

			return EventHandled;
		});

		stream.sendStanza(new Stanza("presence")); // Set self to online
		rosterGet();
		return this.trigger("status/online", {});
	}

	public function usePassword(password: String):Void {
		this.stream.trigger("auth/password", { password: password });
	}

	/* Return array of chats, sorted by last activity */
	public function getChats():ChatList {
		return chats;
	}

	public function getDirectChat(chatId:String, triggerIfNew:Bool = true):DirectChat {
		for (chat in chats) {
			if (Std.isOfType(chat, DirectChat) && chat.chatId == chatId) {
				return Std.downcast(chat, DirectChat);
			}
		}
		var chat = new DirectChat(this, this.stream, chatId);
		chats.unshift(chat);
		if (triggerIfNew) this.trigger("chats/update", [chat]);
		return chat;
	}

	public function chatActivity(chat: Chat) {
		var idx = chats.indexOf(chat);
		if (idx > 0) {
			chats.splice(idx, 1);
			chats.unshift(chat);
			this.trigger("chats/update", []);
		}
	}

	/* Internal-ish methods */
	public function sendQuery(query:GenericQuery) {
		this.stream.sendIq(query.getQueryStanza(), query.handleResponse);
	}

	public function sendStanza(stanza:Stanza) {
		stream.sendStanza(stanza);
	}

	private function rosterGet() {
		var rosterGet = new RosterGet();
		rosterGet.onFinished(() -> {
			for (item in rosterGet.getResult()) {
				getDirectChat(item.jid, false);
			}
			this.trigger("chats/update", chats);
		});
		sendQuery(rosterGet);
	}
}
