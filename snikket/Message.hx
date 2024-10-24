package snikket;

using Lambda;
using StringTools;

enum abstract MessageDirection(Int) {
	var MessageReceived;
	var MessageSent;
}

enum abstract MessageStatus(Int) {
	var MessagePending; // Message is waiting in client for sending
	var MessageDeliveredToServer; // Server acknowledged receipt of the message
	var MessageDeliveredToDevice; //The message has been delivered to at least one client device
	var MessageFailedToSend; // There was an error sending this message
}

enum abstract MessageType(Int) {
	var MessageChat;
	var MessageCall;
	var MessageChannel;
	var MessageChannelPrivate;
}

enum MessageStanza {
	ErrorMessageStanza(stanza: Stanza);
	ChatMessageStanza(message: ChatMessage);
	ReactionUpdateStanza(update: ReactionUpdate);
	UnknownMessageStanza(stanza: Stanza);
}

@:nullSafety(Strict)
class Message {
	public final chatId: String;
	public final senderId: String;
	public final threadId: Null<String>;
	public final parsed: MessageStanza;

	private function new(chatId: String, senderId: String, threadId: Null<String>, parsed: MessageStanza) {
		this.chatId = chatId;
		this.senderId = senderId;
		this.threadId = threadId;
		this.parsed = parsed;
	}

	public static function fromStanza(stanza:Stanza, localJid:JID, ?inputTimestamp: String):Message {
		final fromAttr = stanza.attr.get("from");
		final from = fromAttr == null ? localJid.domain : fromAttr;
		if (stanza.attr.get("type") == "error") return new Message(from, from, null, ErrorMessageStanza(stanza));

		var msg = new ChatMessage();
		final timestamp = stanza.findText("{urn:xmpp:delay}delay@stamp") ?? inputTimestamp ?? Date.format(std.Date.now());
		msg.timestamp = timestamp;
		msg.threadId = stanza.getChildText("thread");
		msg.lang = stanza.attr.get("xml:lang");
		msg.text = stanza.getChildText("body");
		if (msg.text != null && (msg.lang == null || msg.lang == "")) {
			msg.lang = stanza.getChild("body")?.attr.get("xml:lang");
		}
		msg.from = JID.parse(from);
		final isGroupchat = stanza.attr.get("type") == "groupchat";
		msg.type = isGroupchat ? MessageChannel : MessageChat;
		msg.sender = isGroupchat ? msg.from : msg.from?.asBare();
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
		if (msg.serverIdBy != null && msg.serverIdBy != localJid.asBare().asString()) {
			msg.replyId = msg.serverId;
		} else if (msg.serverIdBy == localJid.asBare().asString()) {
			msg.replyId = msg.localId;
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
			replyTo[isGroupchat ? from.asBare().asString() : from.asString()] = true;
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
					return new Message(msg.chatId(), msg.senderId(), msg.threadId, UnknownMessageStanza(stanza));
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
			return new Message(msg.chatId(), msg.senderId(), msg.threadId, UnknownMessageStanza(stanza));
		}

		final reactionsEl = stanza.getChild("reactions", "urn:xmpp:reactions:0");
		if (reactionsEl != null) {
			// A reaction update is never also a chat message
			final reactions = reactionsEl.allTags("reaction").map((r) -> r.getText());
			final reactionId = reactionsEl.attr.get("id");
			if (reactionId != null) {
				return new Message(msg.chatId(), msg.senderId(), msg.threadId, ReactionUpdateStanza(new ReactionUpdate(
					stanza.attr.get("id") ?? ID.long(),
					isGroupchat ? reactionId : null,
					isGroupchat ? msg.chatId() : null,
					isGroupchat ? null : reactionId,
					msg.chatId(),
					timestamp,
					msg.senderId(),
					reactions
				)));
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

		final jmi = stanza.getChild(null, "urn:xmpp:jingle-message:0");
		if (jmi != null) {
			msg.type = MessageCall;
			msg.payloads.push(jmi);
			if (msg.text == null) msg.text = "call " + jmi.name;
			if (jmi.name != "propose") {
				msg.versions = [msg.clone()];
			}
			// The session id is what really identifies us
			Reflect.setField(msg, "localId", jmi.attr.get("id"));
		}

		if (msg.text == null && msg.attachments.length < 1) return new Message(msg.chatId(), msg.senderId(), msg.threadId, UnknownMessageStanza(stanza));

		for (fallback in stanza.allTags("fallback", "urn:xmpp:fallback:0")) {
			msg.payloads.push(fallback);
		}

		final unstyled = stanza.getChild("unstyled", "urn:xmpp:styling:0");
		if (unstyled != null) {
			msg.payloads.push(unstyled);
		}

		final html = stanza.getChild("html", "http://jabber.org/protocol/xhtml-im");
		if (html != null) {
			msg.payloads.push(html);
		}

		final reply = stanza.getChild("reply", "urn:xmpp:reply:0");
		if (reply != null) {
			final replyToJid = reply.attr.get("to");
			final replyToID = reply.attr.get("id");

			final text = msg.text;
			if (text != null && EmojiUtil.isOnlyEmoji(text.trim())) {
				return new Message(msg.chatId(), msg.senderId(), msg.threadId, ReactionUpdateStanza(new ReactionUpdate(
					stanza.attr.get("id") ?? ID.long(),
					isGroupchat ? replyToID : null,
					isGroupchat ? msg.chatId() : null,
					isGroupchat ? null : replyToID,
					msg.chatId(),
					timestamp,
					msg.senderId(),
					[text.trim()],
					true
				)));
			}

			if (html != null) {
				final body = html.getChild("body", "http://www.w3.org/1999/xhtml");
				if (body != null) {
					final els = body.allTags();
					if (els.length == 1 && els[0].name == "img") {
						final hash = Hash.fromUri(els[0].attr.get("src") ?? "");
						if (hash != null) {
							return new Message(msg.chatId(), msg.senderId(), msg.threadId, ReactionUpdateStanza(new ReactionUpdate(
								stanza.attr.get("id") ?? ID.long(),
								isGroupchat ? replyToID : null,
								isGroupchat ? msg.chatId() : null,
								isGroupchat ? null : replyToID,
								msg.chatId(),
								timestamp,
								msg.senderId(),
								[hash.serializeUri()],
								true
							)));
						}
					}
				}
			}

			if (replyToID != null) {
				// Reply stub
				final replyToMessage = new ChatMessage();
				replyToMessage.from = replyToJid == null ? null : JID.parse(replyToJid);
				replyToMessage.replyId = replyToID;
				msg.replyToMessage = replyToMessage;
			}
		}

		final replace = stanza.getChild("replace", "urn:xmpp:message-correct:0");
		final replaceId  = replace?.attr?.get("id");
		if (replaceId != null) {
			msg.versions = [msg.clone()];
			Reflect.setField(msg, "localId", replaceId);
		}

		return new Message(msg.chatId(), msg.senderId(), msg.threadId, ChatMessageStanza(msg));
	}
}
