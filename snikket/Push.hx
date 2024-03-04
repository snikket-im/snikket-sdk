package snikket;

import snikket.ChatMessage;
import snikket.JID;
import snikket.Notification;
import snikket.Persistence;
import snikket.Stanza;

// this code should expect to be called from a different context to the app

@:expose
function receive(data: String, persistence: Persistence) {
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
		return Notification.fromChatMessage(message);
	} else {
		return Notification.fromThinStanza(stanza);
	}
}
