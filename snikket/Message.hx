package snikket;

using Lambda;

enum MessageDirection {
	MessageReceived;
	MessageSent;
}

enum MessageStatus {
	MessagePending; // Message is waiting in client for sending
	MessageDeliveredToServer; // Server acknowledged receipt of the message
	MessageDeliveredToDevice; //The message has been delivered to at least one client device
	MessageFailedToSend; // There was an error sending this message
}

enum MessageStanza {
	ErrorMessageStanza(stanza: Stanza);
	ChatMessageStanza(message: ChatMessage);
	ReactionUpdateStanza(update: ReactionUpdate);
	UnknownMessageStanza(stanza: Stanza);
}

@:nullSafety(Strict)
class Message {
	public static function fromStanza(stanza:Stanza, localJid:JID, ?inputTimestamp: String):MessageStanza {
		if (stanza.attr.get("type") == "error") return ErrorMessageStanza(stanza);

		var msg = new ChatMessage();
		final timestamp = stanza.findText("{urn:xmpp:delay}delay@stamp") ?? inputTimestamp ?? Date.format(std.Date.now());
		msg.timestamp = timestamp;
		msg.threadId = stanza.getChildText("thread");
		msg.lang = stanza.attr.get("xml:lang");
		msg.text = stanza.getChildText("body");
		if (msg.text != null && (msg.lang == null || msg.lang == "")) {
			msg.lang = stanza.getChild("body")?.attr.get("xml:lang");
		}
		final from = stanza.attr.get("from");
		msg.from = from == null ? null : JID.parse(from);
		msg.groupchat = stanza.attr.get("type") == "groupchat";
		msg.sender = stanza.attr.get("type") == "groupchat" ? msg.from : msg.from?.asBare();
		final localJidBare = localJid.asBare();
		final domain = localJid.domain;
		final to = stanza.attr.get("to");
		msg.to = to == null ? localJid : JID.parse(to);

		if (msg.from != null && msg.from.equals(localJidBare)) {
			var carbon = stanza.getChild("received", "urn:xmpp:carbons:2");
			if (carbon == null) carbon = stanza.getChild("sent", "urn:xmpp:carbons:2");
			if (carbon != null) {
				var fwd = carbon.getChild("forwarded", "urn:xmpp:forward:0");
				if(fwd != null) return fromStanza(fwd.getFirstChild(), localJid);
			}
		}

		final localId = stanza.attr.get("id");
		if (localId != null) msg.localId = localId;
		var altServerId = null;
		for (stanzaId in stanza.allTags("stanza-id", "urn:xmpp:sid:0")) {
			final id = stanzaId.attr.get("id");
			if ((stanzaId.attr.get("by") == domain || stanzaId.attr.get("by") == localJidBare.asString()) && id != null) {
				msg.serverIdBy = localJidBare.asString();
				msg.serverId = id;
				break;
			}
			altServerId = stanzaId;
		}
		if (msg.serverId == null && altServerId != null && stanza.attr.get("type") != "error") {
			final id = altServerId.attr.get("id");
			if (id != null) {
				msg.serverId = id;
				msg.serverIdBy = altServerId.attr.get("by");
			}
		}
		msg.direction = (msg.to == null || msg.to.asBare().equals(localJidBare)) ? MessageReceived : MessageSent;
		if (msg.from != null && msg.from.asBare().equals(localJidBare)) msg.direction = MessageSent;
		msg.status = msg.direction == MessageReceived ? MessageDeliveredToDevice : MessageDeliveredToServer; // Delivered to us, a device

		final recipients: Map<String, Bool> = [];
		final replyTo: Map<String, Bool> = [];
		if (msg.to != null) {
			recipients[msg.to.asBare().asString()] = true;
		}
		final from = msg.from;
		if (msg.direction == MessageReceived && from != null) {
			replyTo[stanza.attr.get("type") == "groupchat" ? from.asBare().asString() : from.asString()] = true;
		} else if(msg.to != null) {
			replyTo[msg.to.asString()] = true;
		}

		final addresses = stanza.getChild("addresses", "http://jabber.org/protocol/address");
		var anyExtendedReplyTo = false;
		if (addresses != null) {
			for (address in addresses.allTags("address")) {
				final jid = address.attr.get("jid");
				if (address.attr.get("type") == "noreply") {
					replyTo.clear();
				} else if (jid == null) {
					trace("No support for addressing to non-jid", address);
					return UnknownMessageStanza(stanza);
				} else if (address.attr.get("type") == "to" || address.attr.get("type") == "cc") {
					recipients[JID.parse(jid).asBare().asString()] = true;
					if (!anyExtendedReplyTo) replyTo[JID.parse(jid).asString()] = true; // reply all
				} else if (address.attr.get("type") == "replyto" || address.attr.get("type") == "replyroom") {
					if (!anyExtendedReplyTo) {
						replyTo.clear();
						anyExtendedReplyTo = true;
					}
					replyTo[JID.parse(jid).asString()] = true;
				} else if (address.attr.get("type") == "ofrom") {
					if (JID.parse(jid).domain == msg.sender?.domain) {
						// TODO: check that domain supports extended addressing
						msg.sender = JID.parse(jid).asBare();
					}
				}
			}
		}

		msg.recipients = ({ iterator: () -> recipients.keys() }).map((s) -> JID.parse(s));
		msg.recipients.sort((x, y) -> Reflect.compare(x.asString(), y.asString()));
		msg.replyTo = ({ iterator: () -> replyTo.keys() }).map((s) -> JID.parse(s));
		msg.replyTo.sort((x, y) -> Reflect.compare(x.asString(), y.asString()));

		final msgFrom = msg.from;
		if (msg.direction == MessageReceived && msgFrom != null && msg.replyTo.find((r) -> r.asBare().equals(msgFrom.asBare())) == null) {
			trace("Don't know what chat message without from in replyTo belongs in", stanza);
			return UnknownMessageStanza(stanza);
		}

		final reactionsEl = stanza.getChild("reactions", "urn:xmpp:reactions:0");
		if (reactionsEl != null) {
			// A reaction update is never also a chat message
			final reactions = reactionsEl.allTags("reaction").map((r) -> r.getText());
			final reactionId = reactionsEl.attr.get("id");
			if (reactionId != null) {
				return ReactionUpdateStanza(new ReactionUpdate(
					stanza.attr.get("id") ?? ID.long(),
					stanza.attr.get("type") == "groupchat" ? reactionId : null,
					stanza.attr.get("type") != "groupchat" ? reactionId : null,
					msg.chatId(),
					timestamp,
					msg.senderId(),
					reactions
				));
			}
		}

		for (ref in stanza.allTags("reference", "urn:xmpp:reference:0")) {
			if (ref.attr.get("begin") == null && ref.attr.get("end") == null) {
				final sims = ref.getChild("media-sharing", "urn:xmpp:sims:1");
				if (sims != null) msg.attachSims(sims);
			}
		}

		for (sims in stanza.allTags("media-sharing", "urn:xmpp:sims:1")) {
			msg.attachSims(sims);
		}

		if (msg.text == null && msg.attachments.length < 1) return UnknownMessageStanza(stanza);

		for (fallback in stanza.allTags("fallback", "urn:xmpp:fallback:0")) {
			msg.payloads.push(fallback);
		}

		final unstyled = stanza.getChild("unstyled", "urn:xmpp:styling:0");
		if (unstyled != null) {
			msg.payloads.push(unstyled);
		}

		final reply = stanza.getChild("reply", "urn:xmpp:reply:0");
		if (reply != null) {
			final replyToJid = reply.attr.get("to");
			final replyToID = reply.attr.get("id");
			if (replyToID != null) {
				// Reply stub
				final replyToMessage = new ChatMessage();
				replyToMessage.groupchat = msg.groupchat;
				replyToMessage.from = replyToJid == null ? null : JID.parse(replyToJid);
				if (msg.groupchat) {
					replyToMessage.serverId = replyToID;
				} else {
					replyToMessage.localId = replyToID;
				}
				msg.replyToMessage = replyToMessage;
			}
		}

		final replace = stanza.getChild("replace", "urn:xmpp:message-correct:0");
		final replaceId  = replace?.attr?.get("id");
		if (replaceId != null) {
			msg.versions = [msg.clone()];
			Reflect.setField(msg, "localId", replaceId);
		}

		return ChatMessageStanza(msg);
	}
}
