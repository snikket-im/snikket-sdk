package xmpp;

import xmpp.ID;
import xmpp.MessageSync;
import xmpp.ChatMessage;
import xmpp.Chat;
import xmpp.GenericStream;
import xmpp.queries.MAMQuery;

enum ChatType {
	ChatTypeDirect;
	ChatTypeGroup;
	ChatTypePublic;
}

abstract class Chat {
	private var client:Client;
	private var stream:GenericStream;
	public var chatId(default, null):String;
	public var type(default, null):Null<ChatType>;

	private function new(client:Client, stream:GenericStream, chatId:String, type:ChatType) {
		this.client = client;
		this.stream = stream;
		this.chatId = chatId;
	}

	abstract public function sendMessage(message:ChatMessage):Void;

	abstract public function getMessages(beforeId:Null<String>, handler:MessageListHandler):MessageSync;

	public function isDirectChat():Bool { return type.match(ChatTypeDirect); };
	public function isGroupChat():Bool  { return type.match(ChatTypeGroup);  };
	public function isPublicChat():Bool { return type.match(ChatTypePublic); };

	public function onMessage(handler:ChatMessage->Void):Void {
		this.stream.on("message", function(event) {
			final stanza:Stanza = event.stanza;
			final from = JID.parse(stanza.attr.get("from"));
			if (from.asBare() != JID.parse(this.chatId)) return EventUnhandled;

			final chatMessage = ChatMessage.fromStanza(stanza, this.client.jid);
			if (chatMessage != null) handler(chatMessage);

			return EventUnhandled; // Allow others to get this event as well
		});
	}
}

class DirectChat extends Chat {
	public function new(client:Client, stream:GenericStream, chatId:String) {
		super(client, stream, chatId, ChatTypeDirect);
	}

	public function getMessages(beforeId:Null<String>, handler:MessageListHandler):MessageSync {
		var filter:MAMQueryParams = { with: this.chatId };
		if (beforeId != null) filter.page = { before: beforeId };
		var sync = new MessageSync(this.client, this.stream, filter);
		sync.onMessages(handler);
		sync.fetchNext();
		return sync;
	}

	public function sendMessage(message:ChatMessage):Void {
		client.chatActivity(this);
		client.sendStanza(message.asStanza());
	}

	public function bookmark() {
		stream.sendIq(
			new Stanza("iq", { type: "set", id: ID.short() })
				.tag("query", { xmlns: "jabber:iq:roster" })
				.tag("item", { jid: chatId })
				.up().up(),
			(response) -> {
				if (response.attr.get("type") == "error") return;
				stream.sendStanza(new Stanza("presence", { to: chatId, type: "subscribe", id: ID.short() }));
				stream.sendStanza(new Stanza("presence", { to: chatId, type: "subscribed", id: ID.short() }));
			}
		);
	}
}
