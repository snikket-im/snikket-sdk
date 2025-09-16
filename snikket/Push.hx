package snikket;

import snikket.ChatMessage;
import snikket.JID;
import snikket.Notification;
import snikket.Persistence;
import snikket.Stanza;

#if cpp
import HaxeCBridge;
#end

// this code should expect to be called from a different context to the app

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Push {
	public static function receive(data: String, persistence: Persistence) {
		var stanza = Stanza.parse(data);
		if (stanza == null) return null;
		if (stanza.name == "envelope" && stanza.attr.get("xmlns") == "urn:xmpp:sce:1") {
			stanza = stanza.getChild("content").getFirstChild();
		}
		if (stanza.name == "forwarded" && stanza.attr.get("xmlns") == "urn:xmpp:forward:0") {
			stanza = stanza.getChild("message", "jabber:client");
		}
		if (stanza.attr.get("to") == null) return null;
		// Assume incoming message
		final message = ChatMessage.fromStanza(stanza, JID.parse(stanza.attr.get("to")).asBare());
		if (message != null) {
			persistence.storeMessages(message.account(), [message]);
			return Notification.fromChatMessage(message);
		} else {
			return Notification.fromThinStanza(stanza);
		}
	}
}
