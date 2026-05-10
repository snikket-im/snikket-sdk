package borogove;

import borogove.ChatMessage;
import borogove.JID;
import borogove.Notification;
import borogove.Persistence;
import borogove.Stanza;

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
	/**
		Receive a new push notification from some external system

		@param data the raw data from the push
		@param persistence the persistence layer to write into
		@returns a Notification representing the push data
	**/
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
			// TODO: this puts every push at the same sortId until the next sync
			(message.type == MessageChannel ?
				persistence.syncPoint(message.account(), message.chatId()).then(point -> point?.sortId ?? "a ") :
				persistence.getStreamManagement(message.account()).then(data -> data.sortId)
			).then(sortId -> {
				final sortId = FractionalIndexing.between(sortId, null, FractionalIndexing.BASE_95_DIGITS);
				final toStore = ChatMessage.fromStanza(
					stanza,
					JID.parse(stanza.attr.get("to")).asBare(),
					(builder, stanza) -> {
						builder.sortId = sortId;
						return builder;
					}
				);
				persistence.storeMessages(message.account(), [toStore]);
			});
			return Notification.fromChatMessage(message);
		} else {
			return Notification.fromThinStanza(stanza);
		}
	}
}
