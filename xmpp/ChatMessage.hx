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

	public static function fromStanza(stanza:Stanza, localJid:String):ChatMessage {
		var msg = new ChatMessage();
		msg.text = stanza.getChildText("body");
		msg.to = stanza.attr.get("to");
		msg.from = stanza.attr.get("from");
		final domain = JID.parse(localJid).domain;
		for (stanzaId in stanza.allTags("stanza-id", "urn:xmpp:sid:0")) {
			if (stanzaId.attr.get("by") == domain) {
				msg.serverId = stanzaId.attr.get("id");
				break;
			}
		}
		msg.direction = (msg.to == localJid) ? MessageReceived : MessageSent;
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

	public function isIncoming():Bool {
		return direction == MessageReceived;
	}
}

