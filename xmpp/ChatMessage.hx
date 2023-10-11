package xmpp;

import haxe.Exception;

import xmpp.JID;

enum MessageDirection {
	MessageReceived;
	MessageSent;
}

class ChatAttachment {
	public var url(default, null):String = null;
	public var description(default, null):String = null;
}

@:expose
@:nullSafety(Strict)
class ChatMessage {
	public var localId (default, set) : Null<String> = null;
	public var serverId (default, set) : Null<String> = null;

	public var timestamp (default, set) : Null<String> = null;

	private var to: Null<JID> = null;
	private var from: Null<JID> = null;

	var threadId (default, null): Null<String> = null;

	public var attachments : Array<ChatAttachment> = [];

	public var text (default, null): Null<String> = null;
	public var lang (default, null): Null<String> = null;

	private var direction: MessageDirection = MessageReceived;

	public function new() { }

	public static function fromStanza(stanza:Stanza, localJidStr:String):Null<ChatMessage> {
		var msg = new ChatMessage();
		msg.lang = stanza.attr.get("xml:lang");
		msg.text = stanza.getChildText("body");
		if (msg.text != null && (msg.lang == null || msg.lang == "")) {
			msg.lang = stanza.getChild("body")?.attr.get("xml:lang");
		}
		final to = stanza.attr.get("to");
		msg.to = to == null ? null : JID.parse(to);
		final from = stanza.attr.get("from");
		msg.from = from == null ? null : JID.parse(from);
		final localJid = JID.parse(localJidStr);
		final localJidBare = localJid.asBare();
		final domain = localJid.domain;

		if (msg.from != null && msg.from.equals(localJidBare)) {
			var carbon = stanza.getChild("received", "urn:xmpp:carbons:2");
			if (carbon == null) carbon = stanza.getChild("sent", "urn:xmpp:carbons:2");
			if (carbon != null) {
				var fwd = carbon.getChild("forwarded", "urn:xmpp:forward:0");
				if(fwd != null) return fromStanza(fwd.getFirstChild(), localJidStr);
			}
		}

		for (stanzaId in stanza.allTags("stanza-id", "urn:xmpp:sid:0")) {
			final id = stanzaId.attr.get("id");
			if ((stanzaId.attr.get("by") == domain || stanzaId.attr.get("by") == localJidBare.asString()) && id != null) {
				msg.serverId = id;
				break;
			}
		}
		msg.direction = (msg.to == null || msg.to.asBare().equals(localJidBare)) ? MessageReceived : MessageSent;

		if (msg.text == null) return null;

		return msg;
	}

	public function set_localId(localId:String):String {
		if(this.localId != null) {
			throw new Exception("Message already has a localId set");
		}
		return this.localId = localId;
	}

	public function set_serverId(serverId:String):String {
		if(this.serverId != null) {
			throw new Exception("Message already has a serverId set");
		}
		return this.serverId = serverId;
	}

	public function set_timestamp(timestamp:String):String {
		return this.timestamp = timestamp;
	}

	public function chatId():String {
		return (isIncoming() ? from?.asBare()?.asString() : to?.asBare()?.asString()) ?? throw "from or to is null";
	}

	public function account():String {
		return (!isIncoming() ? from?.asBare()?.asString() : to?.asBare()?.asString()) ?? throw "from or to is null";
	}

	public function isIncoming():Bool {
		return direction == MessageReceived;
	}

	public function asStanza():Stanza {
		var attrs: haxe.DynamicAccess<String> = { type: "chat" };
		if (from != null) attrs.set("from", from.asString());
		if (to != null) attrs.set("to", to.asString());
		if (localId != null) attrs.set("id", localId);
		var stanza = new Stanza("message", attrs);
		if (text != null) stanza.textTag("body", text);
		return stanza;
	}
}
