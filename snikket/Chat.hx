package snikket;

import haxe.io.Bytes;
import haxe.io.BytesData;
import snikket.Chat;
import snikket.ChatMessage;
import snikket.Color;
import snikket.GenericStream;
import snikket.ID;
import snikket.Message;
import snikket.MessageSync;
import snikket.jingle.PeerConnection;
import snikket.jingle.Session;
import snikket.queries.DiscoInfoGet;
import snikket.queries.MAMQuery;
using Lambda;

#if cpp
import HaxeCBridge;
#end

enum abstract UiState(Int) {
	var Pinned;
	var Open; // or Unspecified
	var Closed; // Archived
}

enum abstract UserState(Int) {
	var Gone;
	var Inactive;
	var Active;
	var Composing;
	var Paused;
}

#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
abstract class Chat {
	private var client:Client;
	private var stream:GenericStream;
	private var persistence:Persistence;
	@:allow(snikket)
	private var avatarSha1:Null<BytesData> = null;
	private var presence:Map<String, Presence> = [];
	private var trusted:Bool = false;
	/**
		ID of this Chat
	**/
	public var chatId(default, null):String;
	@:allow(snikket)
	private var jingleSessions: Map<String, snikket.jingle.Session> = [];
	private var displayName:String;
	/**
		Current state of this chat
	**/
	@:allow(snikket)
	public var uiState(default, null): UiState = Open;
	public var isBlocked(default, null): Bool = false;
	@:allow(snikket)
	private var extensions: Stanza;
	private var _unreadCount = 0;
	private var lastMessage: Null<ChatMessage>;
	private var readUpToId: Null<String>;
	@:allow(snikket)
	private var readUpToBy: Null<String>;
	private var isTyping = false;
	private var typingThread: Null<String> = null;
	private var typingTimer: haxe.Timer = null;
	private var isActive: Null<Bool> = null;
	private var activeThread: Null<String> = null;

	@:allow(snikket)
	private function new(client:Client, stream:GenericStream, persistence:Persistence, chatId:String, uiState = Open, isBlocked = false, extensions: Null<Stanza> = null, readUpToId: Null<String> = null, readUpToBy: Null<String> = null) {
		this.client = client;
		this.stream = stream;
		this.persistence = persistence;
		this.chatId = chatId;
		this.uiState = uiState;
		this.isBlocked = isBlocked;
		this.extensions = extensions ?? new Stanza("extensions", { xmlns: "urn:xmpp:bookmarks:1" });
		this.readUpToId = readUpToId;
		this.readUpToBy = readUpToBy;
		this.displayName = chatId;
	}

	@:allow(snikket)
	abstract private function prepareIncomingMessage(message:ChatMessage, stanza:Stanza):ChatMessage;

	/**
		Fetch a page of messages before some point

		@param beforeId id of the message to look before
		@param beforeTime timestamp of the message to look before,
		       String in format YYYY-MM-DDThh:mm:ss[.sss]+00:00
		@param handler takes one argument, an array of ChatMessage that are found
	**/
	abstract public function getMessagesBefore(beforeId:Null<String>, beforeTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void;

	/**
		Fetch a page of messages after some point

		@param afterId id of the message to look after
		@param afterTime timestamp of the message to look after,
		       String in format YYYY-MM-DDThh:mm:ss[.sss]+00:00
		@param handler takes one argument, an array of ChatMessage that are found
	**/
	abstract public function getMessagesAfter(afterId:Null<String>, afterTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void;

	/**
		Fetch a page of messages around (before, including, and after) some point

		@param aroundId id of the message to look around
		@param aroundTime timestamp of the message to look around,
		       String in format YYYY-MM-DDThh:mm:ss[.sss]+00:00
		@param handler takes one argument, an array of ChatMessage that are found
	**/
	abstract public function getMessagesAround(aroundId:Null<String>, aroundTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void;

	private function fetchFromSync(sync: MessageSync, callback: (Array<ChatMessage>)->Void) {
		final promises = [];
		sync.onMessages((messageList) -> {
			final chatMessages = [];
			for (m in messageList.messages) {
				switch (m) {
					case ChatMessageStanza(message):
						final chatMessage = prepareIncomingMessage(message, new Stanza("message", { from: message.senderId() }));
						promises.push(new thenshim.Promise((resolve, reject) -> {
							client.storeMessage(chatMessage, resolve);
						}));
					case ReactionUpdateStanza(update):
						persistence.storeReaction(client.accountId(), update, (m)->{});
					default:
						// ignore
				}
			}
			thenshim.PromiseTools.all(promises).then((chatMessages) -> {
				callback(chatMessages.filter((m) -> m != null && m.chatId() == chatId));
			});
		});
		sync.fetchNext();
	}

	/**
		Send a ChatMessage to this Chat

		@param message the ChatMessage to send
	**/
	abstract public function sendMessage(message:ChatMessage):Void;

	/**
		Signals that all messages up to and including this one have probably
		been displayed to the user

		@param message the ChatMessage most recently displayed
	**/
	abstract public function markReadUpTo(message: ChatMessage):Void;

	/**
		Save this Chat on the server
	**/
	abstract public function bookmark():Void;

	/**
		Get the list of IDs of participants in this Chat

		@returns array of IDs
	**/
	abstract public function getParticipants():Array<String>;

	/**
		Get the details for one participant in this Chat

		@param participantId the ID of the participant to look up
	**/
	abstract public function getParticipantDetails(participantId: String):Participant;

	/**
		Correct an already-send message by replacing it with a new one

		@param localId the localId of the message to correct
		       must be the localId of the first version ever sent, not a subsequent correction
		@param message the new ChatMessage to replace it with
	**/
	abstract public function correctMessage(localId:String, message:ChatMessage):Void;

	/**
		Add new reaction to a message in this Chat

		@param m ChatMessage to react to
		@param reaction emoji of the reaction
	**/
	public function addReaction(m:ChatMessage, reaction:String) {
		final toSend = m.reply();
		toSend.text = reaction;
		sendMessage(toSend);
	}

	/**
		Remove an already-sent reaction from a message

		@param m ChatMessage to remove the reaction from
		@param reaction the emoji to remove
	**/
	abstract public function removeReaction(m:ChatMessage, reaction:String):Void;

	abstract private function sendChatState(state: String, threadId: Null<String>):Void;

	/**
		Call this whenever the user is typing, can call on every keystroke

		@param threadId optional, what thread the user has selected if any
		@param content optional, what the user has typed so far
	**/
	public function typing(threadId: Null<String>, content: Null<String>) {
		if (threadId != typingThread && isTyping) {
			// User has switched threads
			sendChatState("paused", typingThread);
			isTyping = false;
		}

		typingThread = threadId;
		if (typingTimer != null) typingTimer.stop();

		if (content == "") {
			isTyping = false;
			sendChatState("active", typingThread);
			if (isActive == null) {
				typingTimer = haxe.Timer.delay(() -> {
					sendChatState("inactive", typingThread);
				}, 30000);
			}
			return;
		}

		typingTimer = haxe.Timer.delay(() -> {
			sendChatState("paused", typingThread);
			isTyping = false;
		}, 10000);

		if (isTyping) return; // No need to keep sending if the other side knows
		isTyping = true;
		sendChatState("composing", typingThread);
	}


	/**
		Call this whenever the user makes a chat or thread "active" in your UX
		If you call this with true you MUST later call it will false

		@param active true if the chat is "active", false otherwise
		@param threadId optional, what thread the user has selected if any
	**/
	public function setActive(active: Bool, threadId: Null<String>) {
		if (typingTimer != null) typingTimer.stop();
		isTyping = false;

		if (isActive && active && threadId != activeThread) {
			sendChatState("inactive", activeThread);
			isActive = false;
		}
		if (isActive != null) {
			if (isActive && active) return;
			if (!isActive && !active) return;
		}
		isActive = active;
		activeThread = threadId;
		sendChatState(active ? "active" : "inactive", activeThread);
	}

	/**
		Archive this chat
	**/
	abstract public function close():Void;

	/**
		Pin or unpin this chat
	**/
	public function togglePinned(): Void {
		uiState = uiState == Pinned ? Open : Pinned;
		persistence.storeChat(client.accountId(), this);
		client.sortChats();
		client.trigger("chats/update", [this]);
	}

	/**
		Block this chat so it will not re-open
	**/
	public function block(reportSpam: Null<ChatMessage>, onServer: Bool): Void {
		if (reportSpam != null && !onServer) throw "Can't report SPAM if not sending to server";
		isBlocked = true;
		if (uiState == Closed) {
			persistence.storeChat(client.accountId(), this);
		} else {
			close(); // close persists
		}
		if (onServer) {
			final iq = new Stanza("iq", { type: "set", id: ID.short() })
				.tag("block", { xmlns: "urn:xmpp:blocking" })
				.tag("item", { jid: chatId });
			if (reportSpam != null) {
				iq
					.tag("report", { xmlns: "urn:xmpp:reporting:1", reason: "urn:xmpp:reporting:spam" })
					.tag("stanza-id", { xmlns: "urn:xmpp:sid:0", by: reportSpam.serverIdBy, id: reportSpam.serverId });
			}
			stream.sendIq(iq, (response) -> {});
		}
	}

	/**
		Unblock this chat so it will open again
	**/
	public function unblock(onServer: Bool): Void {
		isBlocked = false;
		uiState = Open;
		persistence.storeChat(client.accountId(), this);
		client.trigger("chats/update", [this]);
		if (onServer) {
			stream.sendIq(
				new Stanza("iq", { type: "set", id: ID.short() })
					.tag("unblock", { xmlns: "urn:xmpp:blocking" })
					.tag("item", { jid: chatId }).up().up(),
				(response) -> {}
			);
		}
	}

	/**
		An ID of the most recent message in this chat
	**/
	abstract public function lastMessageId():Null<String>;

	/**
		The timestamp of the most recent message in this chat
	**/
	public function lastMessageTimestamp():Null<String> {
		return lastMessage?.timestamp;
	}

	@:allow(snikket)
	private function updateFromBookmark(item: Stanza) {
		final conf = item.getChild("conference", "urn:xmpp:bookmarks:1");
		final fn = conf.attr.get("name");
		if (fn != null) setDisplayName(fn);
		uiState = (conf.attr.get("autojoin") == "1" || conf.attr.get("autojoin") == "true") ? (uiState == Pinned ? Pinned : Open) : Closed;
		extensions = conf.getChild("extensions") ?? new Stanza("extensions", { xmlns: "urn:xmpp:bookmarks:1" });
	}

	/**
		Get the URI image to represent this Chat, or null
	**/
	public function getPhoto(): Null<String> {
		if (avatarSha1 == null || Bytes.ofData(avatarSha1).length < 1) return null;
		return new Hash("sha-1", avatarSha1).toUri();
	}

	/**
		Get the URI to a placeholder image to represent this Chat
	**/
	public function getPlaceholder(): String {
		return Color.defaultPhoto(chatId, getDisplayName().charAt(0).toUpperCase());
	}

	/**
		An ID of the last message displayed to the user
	**/
	public function readUpTo() {
		return readUpToId;
	}

	/**
		The number of message that have not yet been displayed to the user
	**/
	public function unreadCount() {
		return _unreadCount;
	}

	@:allow(snikket)
	private function setUnreadCount(count:Int) {
		_unreadCount = count;
	}

	/**
		A preview of the chat, such as the most recent message body
	**/
	public function preview() {
		if (lastMessage == null) return "";

		return switch (lastMessage.type) {
			case MessageCall:
				lastMessage.isIncoming() ? "Incoming Call" : "Outgoing Call";
			default:
				lastMessage.text;
		}
	}

	@:allow(snikket)
	private function setLastMessage(message:Null<ChatMessage>) {
		lastMessage = message;
	}

	@:allow(snikket)
	private function setDisplayName(fn:String) {
		this.displayName = fn;
	}

	/**
		The display name of this Chat
	**/
	public function getDisplayName() {
		return this.displayName;
	}

	@:allow(snikket)
	private function setPresence(resource:String, presence:Presence) {
		this.presence.set(resource, presence);
	}

	@:allow(snikket)
	private function setCaps(resource:String, caps:Caps) {
		final presence = presence.get(resource);
		if (presence != null) {
			presence.caps = caps;
			setPresence(resource, presence);
		} else {
			setPresence(resource, new Presence(caps, null));
		}
	}

	@:allow(snikket)
	private function removePresence(resource:String) {
		presence.remove(resource);
	}

	@:allow(snikket)
	private function getCaps():KeyValueIterator<String, Caps> {
		final iter = presence.keyValueIterator();
		return {
			hasNext: iter.hasNext,
			next: () -> {
				final n = iter.next();
				return { key: n.key, value: n.value.caps };
			}
		};
	}

	@:allow(snikket)
	private function getResourceCaps(resource:String):Caps {
		return presence[resource]?.caps ?? new Caps("", [], []);
	}

	@:allow(snikket)
	private function setAvatarSha1(sha1: BytesData) {
		this.avatarSha1 = sha1;
	}

	@:allow(snikket)
	private function setTrusted(trusted:Bool) {
		this.trusted = trusted;
	}

	/**
		Is this a chat with an entity we trust to see our online status?
	**/
	public function isTrusted():Bool {
		return this.trusted;
	}

	@:allow(snikket)
	private function livePresence() {
		return true;
	}

	public function syncing() {
		return !client.inSync;
	}

	/**
		Can audio calls be started in this Chat?
	**/
	public function canAudioCall():Bool {
		for (resource => p in presence) {
			if (p.caps?.features?.contains("urn:xmpp:jingle:apps:rtp:audio") ?? false) return true;
		}

		return false;
	}

	/**
		Can video calls be started in this Chat?
	**/
	public function canVideoCall():Bool {
		for (resource => p in presence) {
			if (p.caps?.features?.contains("urn:xmpp:jingle:apps:rtp:video") ?? false) return true;
		}

		return false;
	}

	/**
		Start a new call in this Chat

		@param audio do we want audio in this call
		@param video do we want video in this call
	**/
	public function startCall(audio: Bool, video: Bool) {
		final session = new OutgoingProposedSession(client, JID.parse(chatId));
		jingleSessions.set(session.sid, session);
		session.propose(audio, video);
	}

	@HaxeCBridge.noemit
	public function addMedia(streams: Array<MediaStream>) {
		if (callStatus() != "ongoing") throw "cannot add media when no call ongoing";
		jingleSessions.iterator().next().addMedia(streams);
	}

	/**
		Accept any incoming calls in this Chat
	**/
	public function acceptCall() {
		for (session in jingleSessions) {
			session.accept();
		}
	}

	/**
		Hangup or reject any calls in this chat
	**/
	public function hangup() {
		for (session in jingleSessions) {
			session.hangup();
			jingleSessions.remove(session.sid);
		}
	}

	/**
		The current status of a call in this chat
	**/
	public function callStatus() {
		for (session in jingleSessions) {
			return session.callStatus();
		}

		return "none";
	}

	/**
		A DTMFSender for a call in this chat, or NULL
	**/
	public function dtmf() {
		for (session in jingleSessions) {
			final dtmf = session.dtmf();
			if (dtmf != null) return dtmf;
		}

		return null;
	}

	/**
		All video tracks in all active calls in this chat
	**/
	public function videoTracks(): Array<MediaStreamTrack> {
		return jingleSessions.flatMap((session) -> session.videoTracks());
	}

	@:allow(snikket)
	private function markReadUpToId(upTo: String, upToBy: String, ?callback: ()->Void) {
		if (upTo == null) return;

		readUpToId = upTo;
		readUpToBy = upToBy;
		persistence.storeChat(client.accountId(), this);
		persistence.getMessagesBefore(client.accountId(), chatId, null, null, (messages) -> {
			var i = messages.length;
			while (--i >= 0) {
				if (messages[i].serverId == readUpToId) break;
			}
			setUnreadCount(messages.length - (i + 1));
			if (callback != null) callback();
		});
	}

	private function publishMds() {
		stream.sendIq(
			new Stanza("iq", { type: "set" })
				.tag("pubsub", { xmlns: "http://jabber.org/protocol/pubsub" })
				.tag("publish", { node: "urn:xmpp:mds:displayed:0" })
				.tag("item", { id: chatId })
				.tag("displayed", { xmlns: "urn:xmpp:mds:displayed:0"})
				.tag("stanza-id", { xmlns: "urn:xmpp:sid:0", id: readUpTo(), by: readUpToBy })
				.up().up().up()
				.tag("publish-options")
				.tag("x", { xmlns: "jabber:x:data", type: "submit" })
				.tag("field", { "var": "FORM_TYPE", type: "hidden" }).textTag("value", "http://jabber.org/protocol/pubsub#publish-options").up()
				.tag("field", { "var": "pubsub#persist_items" }).textTag("value", "true").up()
				.tag("field", { "var": "pubsub#max_items" }).textTag("value", "max").up()
				.tag("field", { "var": "pubsub#send_last_published_item" }).textTag("value", "never").up()
				.tag("field", { "var": "pubsub#access_model" }).textTag("value", "whitelist").up()
				.up().up(),
			(response) -> {
				if (response.attr.get("type") == "error") {
					final preconditionError = response.getChild("error")?.getChild("precondition-not-met", "http://jabber.org/protocol/pubsub#errors");
					if (preconditionError != null) {
						// publish options failed, so force them to be right, what a silly workflow
						stream.sendIq(
							new Stanza("iq", { type: "set" })
								.tag("pubsub", { xmlns: "http://jabber.org/protocol/pubsub#owner" })
								.tag("configure", { node: "urn:xmpp:mds:displayed:0" })
								.tag("x", { xmlns: "jabber:x:data", type: "submit" })
								.tag("field", { "var": "FORM_TYPE", type: "hidden" }).textTag("value", "http://jabber.org/protocol/pubsub#publish-options").up()
								.tag("field", { "var": "pubsub#persist_items" }).textTag("value", "true").up()
								.tag("field", { "var": "pubsub#max_items" }).textTag("value", "max").up()
								.tag("field", { "var": "pubsub#send_last_published_item" }).textTag("value", "never").up()
								.tag("field", { "var": "pubsub#access_model" }).textTag("value", "whitelist").up()
								.up().up().up(),
							(response) -> {
								if (response.attr.get("type") == "result") {
									publishMds();
								}
							}
						);
					}
				}
			}
		);
	}
}

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class DirectChat extends Chat {
	@:allow(snikket)
	private function new(client:Client, stream:GenericStream, persistence:Persistence, chatId:String, uiState = Open, isBlocked = false, extensions: Null<Stanza> = null, readUpToId: Null<String> = null, readUpToBy: Null<String> = null) {
		super(client, stream, persistence, chatId, uiState, isBlocked, extensions, readUpToId, readUpToBy);
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getParticipants(): Array<String> {
		return chatId.split("\n");
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getParticipantDetails(participantId:String): Participant {
		final chat = client.getDirectChat(participantId);
		return new Participant(chat.getDisplayName(), chat.getPhoto(), chat.getPlaceholder());
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getMessagesBefore(beforeId:Null<String>, beforeTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void {
		persistence.getMessagesBefore(client.accountId(), chatId, beforeId, beforeTime, (messages) -> {
			if (messages.length > 0) {
				handler(messages);
			} else {
				var filter:MAMQueryParams = { with: this.chatId };
				if (beforeId != null) filter.page = { before: beforeId };
				var sync  = new MessageSync(this.client, this.stream, filter);
				fetchFromSync(sync, handler);
			}
		});
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getMessagesAfter(afterId:Null<String>, afterTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void {
		persistence.getMessagesAfter(client.accountId(), chatId, afterId, afterTime, (messages) -> {
			if (messages.length > 0) {
				handler(messages);
			} else {
				var filter:MAMQueryParams = { with: this.chatId };
				if (afterId != null) filter.page = { after: afterId };
				var sync  = new MessageSync(this.client, this.stream, filter);
				fetchFromSync(sync, handler);
			}
		});
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getMessagesAround(aroundId:Null<String>, aroundTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void {
		persistence.getMessagesAround(client.accountId(), chatId, aroundId, aroundTime, (messages) -> {
			if (messages.length > 0) {
				handler(messages);
			} else {
				// TODO
				handler([]);
			}
		});
	}

	@:allow(snikket)
	private function prepareIncomingMessage(message:ChatMessage, stanza:Stanza) {
		message.syncPoint = !syncing();
		return message;
	}

	private function prepareOutgoingMessage(message:ChatMessage) {
		message.timestamp = message.timestamp ?? Date.format(std.Date.now());
		message.direction = MessageSent;
		message.from = client.jid;
		message.sender = message.from.asBare();
		message.replyTo = [message.sender];
		message.recipients = getParticipants().map((p) -> JID.parse(p));
		return message;
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function correctMessage(localId:String, message:ChatMessage) {
		final toSend = prepareOutgoingMessage(message.clone());
		message = prepareOutgoingMessage(message);
		message.resetLocalId();
		message.versions = [toSend]; // This is a correction
		message.localId = localId;
		client.storeMessage(message, (corrected) -> {
			toSend.versions = corrected.versions;
			for (recipient in message.recipients) {
				message.to = recipient;
				client.sendStanza(toSend.asStanza());
			}
			if (localId == lastMessage?.localId) {
				setLastMessage(corrected);
				client.trigger("chats/update", [this]);
			}
			client.notifyMessageHandlers(corrected, CorrectionEvent);
		});
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function sendMessage(message:ChatMessage):Void {
		if (typingTimer != null) typingTimer.stop();
		client.chatActivity(this);
		message = prepareOutgoingMessage(message);
		final fromStanza = Message.fromStanza(message.asStanza(), client.jid).parsed;
		switch (fromStanza) {
			case ChatMessageStanza(_):
				client.storeMessage(message, (stored) -> {
					for (recipient in message.recipients) {
						message.to = recipient;
						final stanza = message.asStanza();
						if (isActive != null) {
							isActive = true;
							activeThread = message.threadId;
							stanza.tag("active", { xmlns: "http://jabber.org/protocol/chatstates" }).up();
						}
						client.sendStanza(stanza);
					}
					setLastMessage(message);
					client.trigger("chats/update", [this]);
					client.notifyMessageHandlers(stored, stored.versions.length > 1 ? CorrectionEvent : DeliveryEvent);
				});
			case ReactionUpdateStanza(update):
				persistence.storeReaction(client.accountId(), update, (stored) -> {
					for (recipient in message.recipients) {
						message.to = recipient;
						client.sendStanza(message.asStanza());
					}
					if (stored != null) client.notifyMessageHandlers(stored, ReactionEvent);
				});
			default:
				trace("Invalid message", fromStanza);
				throw "Trying to send invalid message.";
		}
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function removeReaction(m:ChatMessage, reaction:String) {
		// NOTE: doing it this way means no fallback behaviour
		final reactions = [];
		for (areaction => senders in m.reactions) {
			if (areaction != reaction && senders.contains(client.accountId())) reactions.push(areaction);
		}
		final update = new ReactionUpdate(ID.long(), null, null, m.localId, m.chatId(), Date.format(std.Date.now()), client.accountId(), reactions);
		persistence.storeReaction(client.accountId(), update, (stored) -> {
			final stanza = update.asStanza();
			for (recipient in getParticipants()) {
				stanza.attr.set("to", recipient);
				client.sendStanza(stanza);
			}
			if (stored != null) client.notifyMessageHandlers(stored, ReactionEvent);
		});
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function lastMessageId() {
		return lastMessage?.localId ?? lastMessage?.serverId;
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function markReadUpTo(message: ChatMessage) {
		if (readUpTo() == message.localId || readUpTo() == message.serverId) return;
		final upTo = message.localId ?? message.serverId;
		if (upTo == null) return; // Can't mark as read with no id

		// Only send markers for others messages,
		// it's obvious we've read our own
		if (message.isIncoming()) {
			for (recipient in getParticipants()) {
				// TODO: extended addressing when relevant
				final stanza = new Stanza("message", { to: recipient, id: ID.long() })
					.tag("displayed", { xmlns: "urn:xmpp:chat-markers:0", id: upTo }).up();
				if (message.threadId != null) {
					stanza.textTag("thread", message.threadId);
				}
				client.sendStanza(stanza);
			}
		}

		markReadUpToId(message.serverId, message.serverIdBy, () -> {
			publishMds();
			client.trigger("chats/update", [this]);
		});
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function bookmark() {
		stream.sendIq(
			new Stanza("iq", { type: "set" })
				.tag("query", { xmlns: "jabber:iq:roster" })
				.tag("item", { jid: chatId })
				.up().up(),
			(response) -> {
				if (response.attr.get("type") == "error") return;
				stream.sendStanza(new Stanza("presence", { to: chatId, type: "subscribe", id: ID.short() }));
				stream.sendStanza(new Stanza("presence", { to: chatId, type: "subscribed", id: ID.short() }));
			}
		);
	}

	private function sendChatState(state: String, threadId: Null<String>) {
		for (recipient in getParticipants()) {
			final stanza = new Stanza("message", {
					id: ID.long(),
					type: "chat",
					from: client.jid.asString(),
					to: recipient
				})
				.tag(state, { xmlns: "http://jabber.org/protocol/chatstates" })
				.up();
			if (threadId != null) {
				stanza.textTag("thread", threadId);
			}
			stream.sendStanza(stanza);
		}
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function close() {
		if (typingTimer != null) typingTimer.stop();
		// Should this remove from roster?
		uiState = Closed;
		persistence.storeChat(client.accountId(), this);
		sendChatState("gone", null);
		client.trigger("chats/update", [this]);
	}
}

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Channel extends Chat {
	@:allow(snikket)
	private var disco: Caps = new Caps("", [], ["http://jabber.org/protocol/muc"]);
	private var inSync = true;

	@:allow(snikket)
	private function new(client:Client, stream:GenericStream, persistence:Persistence, chatId:String, uiState = Open, isBlocked = false, extensions = null, readUpToId = null, readUpToBy = null, ?disco: Caps) {
		super(client, stream, persistence, chatId, uiState, isBlocked, extensions, readUpToId, readUpToBy);
		if (disco != null) this.disco = disco;
	}

	@:allow(snikket)
	private function selfPing(shouldRefreshDisco = true) {
		if (uiState == Closed){
			client.sendPresence(
				getFullJid().asString(),
				(stanza) -> {
					stanza.attr.set("type", "unavailable");
					return stanza;
				}
			);
			return;
		}

		stream.sendIq(
			new Stanza("iq", { type: "get", to: getFullJid().asString() })
				.tag("ping", { xmlns: "urn:xmpp:ping" }).up(),
			(response) -> {
				if (response.attr.get("type") == "error") {
					final err = response.getChild("error")?.getChild(null, "urn:ietf:params:xml:ns:xmpp-stanzas");
					if (err.name == "service-unavailable" || err.name == "feature-not-implemented") return checkRename(); // Error, success!
					if (err.name == "remote-server-not-found" || err.name == "remote-server-timeout") return checkRename(); // Timeout, retry later
					if (err.name == "item-not-found") return checkRename(); // Nick was changed?
					(shouldRefreshDisco ? refreshDisco : (cb)->cb())(() -> {
						presence = []; // About to ask for a fresh set
						inSync = false;
						client.trigger("chats/update", [this]);
						final desiredFullJid = JID.parse(chatId).withResource(client.displayName());
						client.sendPresence(
							desiredFullJid.asString(),
							(stanza) -> {
								stanza.tag("x", { xmlns: "http://jabber.org/protocol/muc" });
								if (disco.features.contains("urn:xmpp:mam:2")) stanza.tag("history", { maxchars: "0" }).up();
								// TODO: else since (last message we know about)
								stanza.up();
								return stanza;
							}
						);
					});
				} else {
					checkRename();
				}
			}
		);
	}

	private function checkRename() {
		if (nickInUse() != client.displayName()) {
			final desiredFullJid = JID.parse(chatId).withResource(client.displayName());
			client.sendPresence(desiredFullJid.asString());
		}
	}

	override public function setPresence(resource:String, presence:Presence) {
		final oneTen = presence?.mucUser?.allTags("status").find((status) -> status.attr.get("code") == "110");
		if (presence != null && presence.mucUser != null && oneTen == null) {
			final existing = this.presence.get(resource);
			if (existing != null && existing?.mucUser?.allTags("status").find((status) -> status.attr.get("code") == "110") != null) {
				presence.mucUser.tag("status", { code: "110" });
				setPresence(resource, presence);
				return;
			}
		}
		super.setPresence(resource, presence);
		final tripleThree = presence?.mucUser?.allTags("status").find((status) -> status.attr.get("code") == "333");
		if (!inSync && oneTen != null) {
			persistence.lastId(client.accountId(), chatId, doSync);
		}
		if (oneTen != null && tripleThree != null) {
			selfPing();
		}
	}

	private function doSync(lastId: Null<String>) {
		var threeDaysAgo = Date.format(
			DateTools.delta(std.Date.now(), DateTools.days(-3))
		);
		var sync = new MessageSync(
			client,
			stream,
			lastId == null ? { startTime: threeDaysAgo } : { page: { after: lastId } },
			chatId
		);
		sync.setNewestPageFirst(false);
		final chatMessages = [];
		sync.onMessages((messageList) -> {
			final promises = [];
			for (m in messageList.messages) {
				switch (m) {
					case ChatMessageStanza(message):
						for (hash in message.inlineHashReferences()) {
							client.fetchMediaByHash([hash], [message.from]);
						}
						promises.push(new thenshim.Promise((resolve, reject) -> {
							client.storeMessage(message, resolve);
						}));
						if (message.chatId() == chatId) chatMessages.push(message);
					case ReactionUpdateStanza(update):
						promises.push(new thenshim.Promise((resolve, reject) -> {
							persistence.storeReaction(client.accountId(), update, resolve);
						}));
					default:
						// ignore
				}
			}
			thenshim.PromiseTools.all(promises).then((_) -> {
				if (sync.hasMore()) {
					sync.fetchNext();
				} else {
					inSync = true;
					final lastFromSync = chatMessages[chatMessages.length - 1];
					if (lastFromSync != null && (lastMessageTimestamp() == null || Reflect.compare(lastFromSync.timestamp, lastMessageTimestamp()) > 0)) {
						setLastMessage(lastFromSync);
						client.sortChats();
					}
					final readIndex = chatMessages.findIndex((m) -> m.serverId == readUpTo());
					if (readIndex < 0) {
						setUnreadCount(unreadCount() + chatMessages.length);
					} else {
						setUnreadCount(chatMessages.length - readIndex - 1);
					}
					client.trigger("chats/update", [this]);
				}
			});
		});
		sync.onError((stanza) -> {
			if (lastId != null) {
				// Gap in sync, out newest message has expired from server
				doSync(null);
			}
		});
		sync.fetchNext();
	}

	@:allow(snikket)
	private function refreshDisco(?callback: ()->Void) {
		final discoGet = new DiscoInfoGet(chatId);
		discoGet.onFinished(() -> {
			if (discoGet.getResult() != null) {
				disco = discoGet.getResult();
				persistence.storeCaps(discoGet.getResult());
				persistence.storeChat(client.accountId(), this);
			}
			if (callback != null) callback();
		});
		client.sendQuery(discoGet);
	}

	override public function preview() {
		if (lastMessage == null) return super.preview();

		return getParticipantDetails(lastMessage.senderId()).displayName + ": " + super.preview();
	}

	@:allow(snikket)
	override private function livePresence() {
		for (nick => p in presence) {
			for (status in p?.mucUser?.allTags("status") ?? []) {
				if (status.attr.get("code") == "110") {
					return true;
				}
			}
		}
		return false;
	}

	override public function syncing() {
		return !inSync || !livePresence();
	}

	private function nickInUse() {
		for (nick => p in presence) {
			for (status in p?.mucUser?.allTags("status") ?? []) {
				if (status.attr.get("code") == "110") {
					return nick;
				}
			}
		}
		return client.displayName();
	}

	private function getFullJid() {
		return JID.parse(chatId).withResource(nickInUse());
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getParticipants() {
		final jid = JID.parse(chatId);
		return { iterator: () -> presence.keys() }.map((resource) -> new JID(jid.node, jid.domain, resource).asString());
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getParticipantDetails(participantId:String): Participant {
		if (participantId == getFullJid().asString()) {
			final chat = client.getDirectChat(client.accountId(), false);
			return new Participant(client.displayName(), chat.getPhoto(), chat.getPlaceholder());
		} else {
			final nick = JID.parse(participantId).resource;
			final placeholderUri = Color.defaultPhoto(participantId, nick == null ? " " : nick.charAt(0));
			return new Participant(nick, null, placeholderUri);
		}
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getMessagesBefore(beforeId:Null<String>, beforeTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void {
		persistence.getMessagesBefore(client.accountId(), chatId, beforeId, beforeTime, (messages) -> {
			if (messages.length > 0) {
				handler(messages);
			} else {
				var filter:MAMQueryParams = {};
				if (beforeId != null) filter.page = { before: beforeId };
				var sync = new MessageSync(this.client, this.stream, filter, chatId);
				fetchFromSync(sync, handler);
			}
		});
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getMessagesAfter(afterId:Null<String>, afterTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void {
		persistence.getMessagesAfter(client.accountId(), chatId, afterId, afterTime, (messages) -> {
			if (messages.length > 0) {
				handler(messages);
			} else {
				var filter:MAMQueryParams = {};
				if (afterId != null) filter.page = { after: afterId };
				var sync = new MessageSync(this.client, this.stream, filter, chatId);
				fetchFromSync(sync, handler);
			}
		});
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getMessagesAround(aroundId:Null<String>, aroundTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void {
		persistence.getMessagesAround(client.accountId(), chatId, aroundId, aroundTime, (messages) -> {
			if (messages.length > 0) {
				handler(messages);
			} else {
				// TODO
				handler([]);
			}
		});
	}

	@:allow(snikket)
	private function prepareIncomingMessage(message:ChatMessage, stanza:Stanza) {
		message.syncPoint = !syncing();
		if (message.type == MessageChat) message.type = MessageChannelPrivate;
		message.sender = JID.parse(stanza.attr.get("from")); // MUC always needs full JIDs
		if (message.senderId() == getFullJid().asString()) {
			message.recipients = message.replyTo;
			message.direction = MessageSent;
		}
		return message;
	}

	private function prepareOutgoingMessage(message:ChatMessage) {
		message.type = MessageChannel;
		message.timestamp = message.timestamp ?? Date.format(std.Date.now());
		message.direction = MessageSent;
		message.from = client.jid;
		message.sender = getFullJid();
		message.replyTo = [message.sender];
		message.to = JID.parse(chatId);
		message.recipients = [message.to];
		return message;
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function correctMessage(localId:String, message:ChatMessage) {
		final toSend = prepareOutgoingMessage(message.clone());
		message = prepareOutgoingMessage(message);
		message.resetLocalId();
		message.versions = [toSend]; // This is a correction
		message.localId = localId;
		client.storeMessage(message, (corrected) -> {
			toSend.versions = corrected.versions;
			client.sendStanza(toSend.asStanza());
			if (localId == lastMessage?.localId) {
				setLastMessage(corrected);
				client.trigger("chats/update", [this]);
			}
			client.notifyMessageHandlers(corrected, CorrectionEvent);
		});
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function sendMessage(message:ChatMessage):Void {
		if (typingTimer != null) typingTimer.stop();
		client.chatActivity(this);
		message = prepareOutgoingMessage(message);
		final stanza = message.asStanza();
		// Fake from as it will look on reflection for storage purposes
		stanza.attr.set("from", getFullJid().asString());
		final fromStanza = Message.fromStanza(stanza, client.jid).parsed;
		stanza.attr.set("from", client.jid.asString());
		switch (fromStanza) {
			case ChatMessageStanza(_):
				if (isActive != null) {
					isActive = true;
					activeThread = message.threadId;
					stanza.tag("active", { xmlns: "http://jabber.org/protocol/chatstates" }).up();
				}
				client.storeMessage(message, (stored) -> {
					client.sendStanza(stanza);
					setLastMessage(stored);
					client.trigger("chats/update", [this]);
					client.notifyMessageHandlers(stored, stored.versions.length > 1 ? CorrectionEvent : DeliveryEvent);
				});
			case ReactionUpdateStanza(update):
				persistence.storeReaction(client.accountId(), update, (stored) -> {
					client.sendStanza(stanza);
					if (stored != null) client.notifyMessageHandlers(stored, ReactionEvent);
				});
			default:
				trace("Invalid message", fromStanza);
				throw "Trying to send invalid message.";
		}
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function removeReaction(m:ChatMessage, reaction:String) {
		// NOTE: doing it this way means no fallback behaviour
		final reactions = [];
		for (areaction => senders in m.reactions) {
			if (areaction != reaction && senders.contains(getFullJid().asString())) reactions.push(areaction);
		}
		final update = new ReactionUpdate(ID.long(), m.serverId, m.chatId(), null, m.chatId(), Date.format(std.Date.now()), client.accountId(), reactions);
		persistence.storeReaction(client.accountId(), update, (stored) -> {
			final stanza = update.asStanza();
			stanza.attr.set("to", chatId);
			client.sendStanza(stanza);
			if (stored != null) client.notifyMessageHandlers(stored, ReactionEvent);
		});
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function lastMessageId() {
		return lastMessage?.serverId;
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function markReadUpTo(message: ChatMessage) {
		if (readUpTo() == message.serverId) return;
		final upTo = message.serverId;
		if (upTo == null) return; // Can't mark as read with no id
		final stanza = new Stanza("message", { to: chatId, id: ID.long(), type: "groupchat" })
			.tag("displayed", { xmlns: "urn:xmpp:chat-markers:0", id: upTo }).up();
		if (message.threadId != null) {
			stanza.textTag("thread", message.threadId);
		}
		client.sendStanza(stanza);

		markReadUpToId(upTo, message.serverIdBy, () -> {
			publishMds();
			client.trigger("chats/update", [this]);
		});
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function bookmark() {
		stream.sendIq(
			new Stanza("iq", { type: "set" })
				.tag("pubsub", { xmlns: "http://jabber.org/protocol/pubsub" })
				.tag("publish", { node: "urn:xmpp:bookmarks:1" })
				.tag("item", { id: chatId })
				.tag("conference", { xmlns: "urn:xmpp:bookmarks:1", name: getDisplayName(), autojoin: uiState == Closed ? "false" : "true" })
				.textTag("nick", client.displayName()) // Redundant but some other clients want it
				.addChild(extensions)
				.up().up()
				.tag("publish-options")
				.tag("x", { xmlns: "jabber:x:data", type: "submit" })
				.tag("field", { "var": "FORM_TYPE", type: "hidden" }).textTag("value", "http://jabber.org/protocol/pubsub#publish-options").up()
				.tag("field", { "var": "pubsub#persist_items" }).textTag("value", "true").up()
				.tag("field", { "var": "pubsub#max_items" }).textTag("value", "max").up()
				.tag("field", { "var": "pubsub#send_last_published_item" }).textTag("value", "never").up()
				.tag("field", { "var": "pubsub#access_model" }).textTag("value", "whitelist").up()
				.tag("field", { "var": "pubsub#notify_delete" }).textTag("value", "true").up()
				.tag("field", { "var": "pubsub#notify_retract" }).textTag("value", "true").up()
				.up().up().up().up(),
			(response) -> {
				if (response.attr.get("type") == "error") {
					final preconditionError = response.getChild("error")?.getChild("precondition-not-met", "http://jabber.org/protocol/pubsub#errors");
					if (preconditionError != null) {
						// publish options failed, so force them to be right, what a silly workflow
						stream.sendIq(
							new Stanza("iq", { type: "set" })
								.tag("pubsub", { xmlns: "http://jabber.org/protocol/pubsub#owner" })
								.tag("configure", { node: "urn:xmpp:bookmarks:1" })
								.tag("x", { xmlns: "jabber:x:data", type: "submit" })
								.tag("field", { "var": "FORM_TYPE", type: "hidden" }).textTag("value", "http://jabber.org/protocol/pubsub#publish-options").up()
								.tag("field", { "var": "pubsub#persist_items" }).textTag("value", "true").up()
								.tag("field", { "var": "pubsub#max_items" }).textTag("value", "max").up()
								.tag("field", { "var": "pubsub#send_last_published_item" }).textTag("value", "never").up()
								.tag("field", { "var": "pubsub#access_model" }).textTag("value", "whitelist").up()
								.tag("field", { "var": "pubsub#notify_delete" }).textTag("value", "true").up()
								.tag("field", { "var": "pubsub#notify_retract" }).textTag("value", "true").up()
								.up().up().up(),
							(response) -> {
								if (response.attr.get("type") == "result") {
									bookmark();
								}
							}
						);
					}
				}
			}
		);
	}

	private function sendChatState(state: String, threadId: Null<String>) {
		final stanza = new Stanza("message", {
				id: ID.long(),
				type: "groupchat",
				from: client.jid.asString(),
				to: chatId
			})
			.tag(state, { xmlns: "http://jabber.org/protocol/chatstates" })
			.up();
		if (threadId != null) {
			stanza.textTag("thread", threadId);
		}
		stream.sendStanza(stanza);
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function close() {
		if (typingTimer != null) typingTimer.stop();
		uiState = Closed;
		persistence.storeChat(client.accountId(), this);
		selfPing(false);
		bookmark(); // TODO: what if not previously bookmarked?
		sendChatState("gone", null);
		client.trigger("chats/update", [this]);
	}
}

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class AvailableChat {
	/**
		The ID of the Chat this search result represents
	**/
	public final chatId: String;
	/**
		The display name of this search result
	**/
	public final displayName: Null<String>;
	/**
		A human-readable note associated with this search result
	**/
	public final note: String;
	@:allow(snikket)
	private final caps: Caps;

	/**
		Is this search result a channel?
	**/
	public function isChannel() {
		return caps.isChannel(chatId);
	}

	@:allow(snikket)
	private function new(chatId: String, displayName: Null<String>, note: String, caps: Caps) {
		this.chatId = chatId;
		this.displayName = displayName;
		this.note = note;
		this.caps = caps;
	}
}

@:expose
class SerializedChat {
	public final chatId:String;
	public final trusted:Bool;
	public final avatarSha1:Null<BytesData>;
	public final presence:Map<String, Presence>;
	public final displayName:Null<String>;
	public final uiState:UiState;
	public final isBlocked:Bool;
	public final extensions:String;
	public final readUpToId:Null<String>;
	public final readUpToBy:Null<String>;
	public final disco:Null<Caps>;
	public final klass:String;

	public function new(chatId: String, trusted: Bool, avatarSha1: Null<BytesData>, presence: Map<String, Presence>, displayName: Null<String>, uiState: Null<UiState>, isBlocked: Null<Bool>, extensions: Null<String>, readUpToId: Null<String>, readUpToBy: Null<String>, disco: Null<Caps>, klass: String) {
		this.chatId = chatId;
		this.trusted = trusted;
		this.avatarSha1 = avatarSha1;
		this.presence = presence;
		this.displayName = displayName;
		this.uiState = uiState ?? Open;
		this.isBlocked = isBlocked ?? false;
		this.extensions = extensions ?? "<extensions xmlns='urn:app:bookmarks:1' />";
		this.readUpToId = readUpToId;
		this.readUpToBy = readUpToBy;
		this.disco = disco;
		this.klass = klass;
	}

	public function toChat(client: Client, stream: GenericStream, persistence: Persistence) {
		final extensionsStanza = Stanza.fromXml(Xml.parse(extensions));

		final chat = if (klass == "DirectChat") {
			new DirectChat(client, stream, persistence, chatId, uiState, isBlocked, extensionsStanza, readUpToId, readUpToBy);
		} else if (klass == "Channel") {
			final channel = new Channel(client, stream, persistence, chatId, uiState, isBlocked, extensionsStanza, readUpToId, readUpToBy);
			channel.disco = disco ?? new Caps("", [], ["http://jabber.org/protocol/muc"]);
			channel;
		} else {
			throw "Unknown class: " + klass;
		}
		if (displayName != null) chat.setDisplayName(displayName);
		if (avatarSha1 != null) chat.setAvatarSha1(avatarSha1);
		chat.setTrusted(trusted);
		for (resource => p in presence) {
			chat.setPresence(resource, p);
		}
		return chat;
	}
}
