package borogove;

import borogove.ChatMessage;
import borogove.JID;
import borogove.Message;

#if cpp
import HaxeCBridge;
#end

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Notification {
	public final title: String;
	public final body: String;
	public final accountId: String;
	public final chatId: String;
	public final senderId: String;
	public final messageId: String;
	public final type: MessageType;
	public final callStatus: Null<String>;
	public final callSid: Null<String>;
	public final imageUri: Null<String>;
	public final lang: Null<String>;
	public final timestamp: Null<String>;

	@:allow(borogove)
	private function new(title: String, body: String, accountId: String, chatId: String, senderId: String, messageId: String, type: MessageType, callStatus: Null<String>, callSid: Null<String>, imageUri: Null<String>, lang: Null<String>, timestamp: Null<String>) {
		this.title = title;
		this.body = body;
		this.accountId = accountId;
		this.chatId = chatId;
		this.senderId = senderId;
		this.messageId = messageId;
		this.type = type;
		this.callStatus = callStatus;
		this.callSid = callSid;
		this.imageUri = imageUri;
		this.lang = lang;
		this.timestamp = timestamp;
	}

	@:allow(borogove)
	private static function fromChatMessage(m: ChatMessage) {
		var imageUri = null;
		final attachment = m.attachments[0];
		if (attachment != null) {
			imageUri = attachment.uris[0];
		}
		return new Notification(
			m.type == MessageCall ? "Incoming Call" : "New Message",
			m.text,
			m.account(),
			m.chatId(),
			m.senderId,
			m.serverId,
			m.type,
			m.callStatus(),
			m.callSid(),
			imageUri,
			m.lang,
			m.timestamp
		);
	}

	// Sometimes a stanza has not much in it, so make something generic
	// Assume it is an incoming message of some kind
	@:allow(borogove)
	private static function fromThinStanza(stanza: Stanza) {
		return new Notification(
			"New Message",
			"",
			JID.parse(stanza.attr.get("to")).asBare().asString(),
			JID.parse(stanza.attr.get("from")).asBare().asString(),
			JID.parse(stanza.attr.get("from")).asString(),
			stanza.getChildText("stanza-id", "urn:xmpp:sid:0"),
			MessageChat,
			null,
			null,
			null,
			null,
			null
		);
	}
}
