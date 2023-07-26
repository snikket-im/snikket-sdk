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

class ChatMessage {
	public var localId (default, set) : String = null;
	public var serverId (default, set) : String = null;

	public var timestamp (default, set) : String = null;

	public var to (default, null): String = null;
	public var from (default, null): String = null;

	var threadId (default, null): String = null;
	var replyTo (default, null): String = null;

	var attachments : Array<ChatAttachment> = null;

	public var text (default, null): String = null;

	private var direction:MessageDirection = null;

	public function new() { }

	public static function fromStanza(stanza:Stanza, localJidStr:String):Null<ChatMessage> {
		var msg = new ChatMessage();
		msg.text = stanza.getChildText("body");
		msg.to = stanza.attr.get("to");
		msg.from = stanza.attr.get("from");
		final localJid = JID.parse(localJidStr);
		final localJidBare = localJid.asBare();
		final domain = localJid.domain;
		for (stanzaId in stanza.allTags("stanza-id", "urn:xmpp:sid:0")) {
			if (stanzaId.attr.get("by") == domain || stanzaId.attr.get("by") == localJidBare.asString()) {
				msg.serverId = stanzaId.attr.get("id");
				break;
			}
		}
		msg.direction = (JID.parse(msg.to).asBare().asString() == localJidBare.asString()) ? MessageReceived : MessageSent;

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

	public function conversation():String {
		return direction == MessageReceived ? JID.parse(from).asBare().asString() : JID.parse(to).asBare().asString();
	}

	public function isIncoming():Bool {
		return direction == MessageReceived;
	}

	public function asStanza():Stanza {
		var attrs: haxe.DynamicAccess<String> = { type: "chat" };
		if (from != null) attrs.set("from", from);
		if (to != null) attrs.set("to", to);
		if (localId != null) attrs.set("id", localId);
		var stanza = new Stanza("message", attrs);
		stanza.textTag("body", text);
		return stanza;
	}
}
