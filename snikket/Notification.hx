package snikket;

import snikket.ChatMessage;
import snikket.JID;
import snikket.Message;

@:expose
class Notification {
	public var title (default, null) : String;
	public var body (default, null) : String;
	public var accountId (default, null) : String;
	public var chatId (default, null) : String;
	public var messageId (default, null) : String;
	public var type (default, null) : MessageType;
	public var callStatus (default, null) : Null<String>;
	public var callSid (default, null) : Null<String>;
	public var imageUri (default, null) : Null<String>;
	public var lang (default, null) : Null<String>;
	public var timestamp (default, null) : Null<String>;

	public function new(title: String, body: String, accountId: String, chatId: String, messageId: String, type: MessageType, callStatus: Null<String>, callSid: Null<String>, imageUri: Null<String>, lang: Null<String>, timestamp: Null<String>) {
		this.title = title;
		this.body = body;
		this.accountId = accountId;
		this.chatId = chatId;
		this.messageId = messageId;
		this.type = type;
		this.callStatus = callStatus;
		this.callSid = callSid;
		this.imageUri = imageUri;
		this.lang = lang;
		this.timestamp = timestamp;
	}

	public static function fromChatMessage(m: ChatMessage) {
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
	public static function fromThinStanza(stanza: Stanza) {
		return new Notification(
			"New Message",
			"",
			JID.parse(stanza.attr.get("to")).asBare().asString(),
			JID.parse(stanza.attr.get("from")).asBare().asString(),
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
