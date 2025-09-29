package borogove;

import borogove.Reaction;
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
	ModerateMessageStanza(action: ModerationAction);
	ReactionUpdateStanza(update: ReactionUpdate);
	UnknownMessageStanza(stanza: Stanza);
	UndecryptableMessageStanza(decryptionFailure: EncryptionInfo);
}

@:nullSafety(Strict)
class Message {
	public final chatId: String;
	public final senderId: String;
	public final threadId: Null<String>;
	public final encryption: Null<EncryptionInfo>;
	public final parsed: MessageStanza;

	private function new(chatId: String, senderId: String, threadId: Null<String>, parsed: MessageStanza, encryption:Null<EncryptionInfo>) {
		this.chatId = chatId;
		this.senderId = senderId;
		this.threadId = threadId;
		this.parsed = parsed;
		this.encryption = encryption;
	}

	public static function fromStanza(stanza:Stanza, localJid:JID, ?addContext: (ChatMessageBuilder, Stanza)->ChatMessageBuilder, ?encryptionInfo:EncryptionInfo):Message {
		final fromAttr = stanza.attr.get("from");
		final from = fromAttr == null ? localJid.domain : fromAttr;
		if(encryptionInfo==null) {
			encryptionInfo = EncryptionInfo.fromStanza(stanza);
		}

		if (stanza.attr.get("type") == "error") {
			return new Message(from, from, null, ErrorMessageStanza(stanza), encryptionInfo);
		}

		if(encryptionInfo != null && encryptionInfo.status == DecryptionFailure) {
			trace("Message decryption failure: " + encryptionInfo.reasonText);
			return new Message(from, from, stanza.getChildText("thread"), UndecryptableMessageStanza(encryptionInfo), encryptionInfo);
		}

		var msg = new ChatMessageBuilder();
		msg.stanza = stanza;
		msg.timestamp =stanza.findText("{urn:xmpp:delay}delay@stamp");
		msg.threadId = stanza.getChildText("thread");
		msg.lang = stanza.attr.get("xml:lang");
		msg.text = stanza.getChildText("body");
		if (msg.text != null && (msg.lang == null || msg.lang == "")) {
			msg.lang = stanza.getChild("body")?.attr.get("xml:lang");
		}
		msg.from = JID.parse(from);
		final isGroupchat = stanza.attr.get("type") == "groupchat";
		msg.type = isGroupchat ? MessageChannel : MessageChat;
		if (msg.type == MessageChat && stanza.getChild("x", "http://jabber.org/protocol/muc#user") != null) {
			msg.type = MessageChannelPrivate;
		}
		msg.senderId = (isGroupchat ? msg.from : msg.from?.asBare())?.asString();
		final localJidBare = localJid.asBare();
		final domain = localJid.domain;
		final to = stanza.attr.get("to");
		msg.to = to == null ? localJid : JID.parse(to);
		msg.encryption = encryptionInfo;

		if (msg.from != null && msg.from.equals(localJidBare)) {
			var carbon = stanza.getChild("received", "urn:xmpp:carbons:2");
			if (carbon == null) carbon = stanza.getChild("sent", "urn:xmpp:carbons:2");
			if (carbon != null) {
				var fwd = carbon.getChild("forwarded", "urn:xmpp:forward:0");
				if(fwd != null) return fromStanza(fwd.getFirstChild(), localJid, null, encryptionInfo);
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
					return new Message(msg.chatId(), msg.senderId, msg.threadId, UnknownMessageStanza(stanza), encryptionInfo);
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
					if (JID.parse(jid).domain == msg.from?.domain) {
						// TODO: check that domain supports extended addressing
						msg.senderId = JID.parse(jid).asBare().asString();
					}
				}
			}
		}

		msg.recipients = ({ iterator: () -> recipients.keys() }).map((s) -> JID.parse(s));
		msg.recipients.sort((x, y) -> Reflect.compare(x.asString(), y.asString()));
		msg.replyTo = ({ iterator: () -> replyTo.keys() }).map((s) -> JID.parse(s));
		msg.replyTo.sort((x, y) -> Reflect.compare(x.asString(), y.asString()));

		final msgFrom = msg.from;
		// Not sure why the compiler things we need to use Null<JID> with findFast
		if (msg.direction == MessageReceived && msgFrom != null && Util.findFast(msg.replyTo, @:nullSafety(Off) (r: Null<JID>) -> r.asBare().equals(msgFrom.asBare())) == null) {
			trace("Don't know what chat message without from in replyTo belongs in", stanza);
			return new Message(msg.chatId(), msg.senderId, msg.threadId, UnknownMessageStanza(stanza), encryptionInfo);
		}

		if (addContext != null) msg = addContext(msg, stanza);
		final timestamp = msg.timestamp ?? Date.format(std.Date.now());
		msg.timestamp = timestamp;

		final reactionsEl = stanza.getChild("reactions", "urn:xmpp:reactions:0");
		if (reactionsEl != null) {
			// A reaction update is never also a chat message
			final reactions = reactionsEl.allTags("reaction").map((r) -> r.getText());
			final reactionId = reactionsEl.attr.get("id");
			if (reactionId != null) {
				return new Message(msg.chatId(), msg.senderId, msg.threadId, ReactionUpdateStanza(new ReactionUpdate(
					stanza.attr.get("id") ?? ID.long(),
					isGroupchat ? reactionId : null,
					isGroupchat ? msg.chatId() : null,
					isGroupchat ? null : reactionId,
					msg.chatId(),
					msg.senderId,
					timestamp,
					reactions.map(text -> new Reaction(msg.senderId, timestamp, text, msg.localId)),
					EmojiReactions
				)), encryptionInfo);
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
				msg.versions = [msg.build()];
			}
			// The session id is what really identifies us
			msg.localId = jmi.attr.get("id");
		}

		final retract = stanza.getChild("replace", "urn:xmpp:message-retract:1");
		final fasten = stanza.getChild("apply-to", "urn:xmpp:fasten:0");
		final moderated = retract?.getChild("moderated", "urn:xmpp:message-retract:1") ?? fasten?.getChild("moderated", "urn:xmpp:message-moderate:0");
		final moderateServerId = retract?.attr?.get("id") ?? fasten?.attr?.get("id");
		if (moderated != null && moderateServerId != null && isGroupchat && msg.from != null && msg.from.isBare() && msg.from.asString() == msg.chatId()) {
			final reason = retract?.getChildText("reason") ?? moderated?.getChildText("reason");
			final by = moderated.attr.get("by");
			// TODO: occupant id as well / instead of by?
			return new Message(
				msg.chatId(),
				msg.senderId,
				msg.threadId,
				ModerateMessageStanza(new ModerationAction(msg.chatId(), moderateServerId, timestamp, by, reason)),
				encryptionInfo
			);
		}

		final replace = stanza.getChild("replace", "urn:xmpp:message-correct:0");
		final replaceId  = replace?.attr?.get("id");

		if (msg.text == null && msg.attachments.length < 1 && replaceId == null) return new Message(msg.chatId(), msg.senderId, msg.threadId, UnknownMessageStanza(stanza), encryptionInfo);

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
				return new Message(msg.chatId(), msg.senderId, msg.threadId, ReactionUpdateStanza(new ReactionUpdate(
					stanza.attr.get("id") ?? ID.long(),
					isGroupchat ? replyToID : null,
					isGroupchat ? msg.chatId() : null,
					isGroupchat ? null : replyToID,
					msg.chatId(),
					msg.senderId,
					timestamp,
					[new Reaction(msg.senderId, timestamp, text.trim(), msg.localId)],
					AppendReactions
				)), encryptionInfo);
			}

			if (html != null) {
				final body = html.getChild("body", "http://www.w3.org/1999/xhtml");
				if (body != null) {
					final els = body.allTags();
					if (els.length == 1 && els[0].name == "img") {
						final hash = Hash.fromUri(els[0].attr.get("src") ?? "");
						if (hash != null) {
							return new Message(msg.chatId(), msg.senderId, msg.threadId, ReactionUpdateStanza(new ReactionUpdate(
								stanza.attr.get("id") ?? ID.long(),
								isGroupchat ? replyToID : null,
								isGroupchat ? msg.chatId() : null,
								isGroupchat ? null : replyToID,
								msg.chatId(),
								msg.senderId,
								timestamp,
								[new CustomEmojiReaction(msg.senderId, timestamp, els[0].attr.get("alt") ?? "", hash.serializeUri(), msg.localId)],
								AppendReactions
							)), encryptionInfo);
						}
					}
				}
			}

			if (replyToID != null) {
				// Reply stub
				final replyToMessage = new ChatMessageBuilder();
				replyToMessage.to = replyToJid == msg.senderId ? msg.to : msg.from;
				replyToMessage.from = replyToJid == null ? null : JID.parse(replyToJid);
				replyToMessage.senderId = isGroupchat ? replyToMessage.from?.asString() : replyToMessage.from?.asBare()?.asString();
				replyToMessage.replyId = replyToID;
				if (msg.serverIdBy != null && msg.serverIdBy != localJid.asBare().asString()) {
					replyToMessage.serverId = replyToID;
				} else {
					replyToMessage.localId = replyToID;
				}
				msg.replyToMessage = replyToMessage.build();
			}
		}

		if (replaceId != null) {
			if (msg.versions.length < 1) msg.versions = [msg.build()];
			msg.localId = replaceId;
		}

		return new Message(msg.chatId(), msg.senderId, msg.threadId, ChatMessageStanza(msg.build()), encryptionInfo);
	}
}
