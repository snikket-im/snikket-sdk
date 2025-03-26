package snikket;

import haxe.DynamicAccess;
import haxe.io.Bytes;
import haxe.io.BytesData;
import snikket.Chat;
import snikket.ChatMessage;
import snikket.Color;
import snikket.GenericStream;
import snikket.ID;
import snikket.Message;
import snikket.MessageSync;
import snikket.Reaction;
import snikket.jingle.PeerConnection;
import snikket.jingle.Session;
import snikket.queries.DiscoInfoGet;
import snikket.queries.MAMQuery;
using Lambda;
using StringTools;

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
	@:allow(snikket)
	private var presence:Map<String, Presence> = [];
	private var trusted:Bool = false;
	/**
		ID of this Chat
	**/
	public var chatId(default, null):String;
	@:allow(snikket)
	private var jingleSessions: Map<String, snikket.jingle.Session> = [];
	@:allow(snikket)
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
	private var notificationSettings: Null<{reply: Bool, mention: Bool}> = null;

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
	abstract private function prepareIncomingMessage(message:ChatMessageBuilder, stanza:Stanza):ChatMessageBuilder;

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
		sync.onMessages((messageList) -> {
			final chatMessages = [];
			for (m in messageList.messages) {
				switch (m) {
					case ChatMessageStanza(message):
						chatMessages.push(message);
					case ReactionUpdateStanza(update):
						persistence.storeReaction(client.accountId(), update, (m)->{});
					case ModerateMessageStanza(action):
						client.moderateMessage(action);
					default:
						// ignore
				}
			}
			client.storeMessages(chatMessages, (chatMessages) -> {
				callback(chatMessages.filter((m) -> m != null && m.chatId() == chatId));
			});
		});
		sync.fetchNext();
	}

	/**
		Send a ChatMessage to this Chat

		@param message the ChatMessage to send
	**/
	abstract public function sendMessage(message:ChatMessageBuilder):Void;

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
	abstract public function correctMessage(localId:String, message:ChatMessageBuilder):Void;

	/**
		Add new reaction to a message in this Chat

		@param m ChatMessage to react to
		@param reaction emoji of the reaction
	**/
	public function addReaction(m:ChatMessage, reaction:Reaction) {
		final toSend = m.reply();
		toSend.localId = ID.long();
		reaction.render(
			(text) -> {
				toSend.text = text.replace("\u{fe0f}", "");
				return;
			},
			(text, uri) -> {
				final hash = Hash.fromUri(uri);
				toSend.setHtml('<img alt="' + Util.xmlEscape(text) + '" src="' + Util.xmlEscape(hash == null ? uri : hash.bobUri()) + '" />');
			}
		);
		sendMessage(toSend);
	}

	/**
		Remove an already-sent reaction from a message

		@param m ChatMessage to remove the reaction from
		@param reaction the emoji to remove
	**/
	abstract public function removeReaction(m:ChatMessage, reaction:Reaction):Void;

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
		persistence.storeChats(client.accountId(), [this]);
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
			persistence.storeChats(client.accountId(), [this]);
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
		persistence.storeChats(client.accountId(), [this]);
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
		Update notification preferences
	**/
	public function setNotifications(filtered: Bool, mention: Bool, reply: Bool) {
		if (filtered) {
			notificationSettings = { mention: mention, reply: reply };
		} else {
			notificationSettings = null;
		}
		persistence.storeChats(client.accountId(), [this]);
		#if js
		client.updatePushIfEnabled();
		#end
	}

	/**
		Should notifications be filtered?
	**/
	public function notificationsFiltered() {
		return notificationSettings != null;
	}

	/**
		Should a mention produce a notification?
	**/
	public function notifyMention() {
		return notificationSettings == null || notificationSettings.mention;
	}

	/**
		Should a reply produce a notification?
	**/
	public function notifyReply() {
		return notificationSettings == null || notificationSettings.reply;
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
		if (fn != null) displayName = fn;
		uiState = (conf.attr.get("autojoin") == "1" || conf.attr.get("autojoin") == "true") ? (uiState == Pinned ? Pinned : Open) : Closed;
		extensions = conf.getChild("extensions") ?? new Stanza("extensions", { xmlns: "urn:xmpp:bookmarks:1" });
	}

	@:allow(snikket)
	private function updateFromRoster(item: { fn: Null<String>, subscription: String }) {
		setTrusted(item.subscription == "both" || item.subscription == "from");
		if (item.fn != null && item.fn != "") displayName = item.fn;
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

	public function setDisplayName(fn:String) {
		this.displayName = fn;
		bookmark();
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

	public function setTrusted(trusted:Bool) {
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
		if (readUpTo() == upTo) return;

		readUpToId = upTo;
		readUpToBy = upToBy;
		persistence.storeChats(client.accountId(), [this]);
		persistence.getMessagesBefore(client.accountId(), chatId, null, null, (messages) -> {
			var i = messages.length;
			while (--i >= 0) {
				if (messages[i].serverId == readUpToId || !messages[i].isIncoming()) break;
			}
			setUnreadCount(messages.length - (i + 1));
			if (callback != null) callback();
		});
	}

	private function markReadUpToMessage(message: ChatMessage, ?callback: ()->Void) {
		if (message.serverId == null || message.chatId() != chatId) return;
		if (readUpTo() == message.serverId) return;

		persistence.getMessage(client.accountId(), chatId, readUpTo(), null, (readMessage) -> {
			if (readMessage != null && Reflect.compare(message.timestamp, readMessage.timestamp) <= 0) return;

			markReadUpToId(message.serverId, message.serverIdBy, callback);
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
		return new Participant(chat.getDisplayName(), chat.getPhoto(), chat.getPlaceholder(), chat.chatId == client.accountId());
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
		if (afterId == lastMessageId() && !syncing()) {
			handler([]);
			return;
		}
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
	private function prepareIncomingMessage(message:ChatMessageBuilder, stanza:Stanza) {
		message.syncPoint = !syncing();
		return message;
	}

	private function prepareOutgoingMessage(message:ChatMessageBuilder) {
		message.timestamp = message.timestamp ?? Date.format(std.Date.now());
		message.direction = MessageSent;
		message.from = client.jid;
		message.sender = message.from.asBare();
		message.replyTo = [message.sender];
		message.recipients = getParticipants().map((p) -> JID.parse(p));
		message.to = message.recipients[0];
		return message;
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function correctMessage(localId:String, message:ChatMessageBuilder) {
		final toSendId = message.localId;
		message = prepareOutgoingMessage(message);
		message.versions = [message.build()]; // This is a correction
		message.localId = localId;
		client.storeMessages([message.build()], (corrected) -> {
			message.versions = corrected[0].versions[corrected[0].versions.length - 1]?.localId == localId ? cast corrected[0].versions : [message.build()];
			message.localId = toSendId;
			for (recipient in message.recipients) {
				message.to = recipient;
				client.sendStanza(message.build().asStanza());
			}
			if (localId == lastMessage?.localId) {
				setLastMessage(corrected[0]);
				client.trigger("chats/update", [this]);
			}
			client.notifyMessageHandlers(corrected[0], CorrectionEvent);
		});
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function sendMessage(message: ChatMessageBuilder):Void {
		if (typingTimer != null) typingTimer.stop();
		client.chatActivity(this);
		message = prepareOutgoingMessage(message);
		message.to = message.recipients[0]; // Just pick one for the stanza we re-parse
		final fromStanza = Message.fromStanza(message.build().asStanza(), client.jid).parsed;
		switch (fromStanza) {
			case ChatMessageStanza(_):
				client.storeMessages([message.build()], (stored) -> {
					for (recipient in message.recipients) {
						message.to = recipient;
						final stanza = message.build().asStanza();
						if (isActive != null) {
							isActive = true;
							activeThread = message.threadId;
							stanza.tag("active", { xmlns: "http://jabber.org/protocol/chatstates" }).up();
						}
						client.sendStanza(stanza);
					}
					setLastMessage(message.build());
					client.trigger("chats/update", [this]);
					client.notifyMessageHandlers(stored[0], stored[0].versions.length > 1 ? CorrectionEvent : DeliveryEvent);
				});
			case ReactionUpdateStanza(update):
				persistence.storeReaction(client.accountId(), update, (stored) -> {
					for (recipient in message.recipients) {
						message.to = recipient;
						client.sendStanza(message.build().asStanza());
					}
					if (stored != null) client.notifyMessageHandlers(stored, ReactionEvent);
				});
			default:
				trace("Invalid message", fromStanza);
				throw "Trying to send invalid message.";
		}
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function removeReaction(m:ChatMessage, reaction:Reaction) {
		if (Std.isOfType(reaction, CustomEmojiReaction)) {
			if (reaction.envelopeId == null) throw "Cannot remove custom emoji reaction without envelopeId";
			final correct = m.reply();
			correct.localId = ID.long();
			correct.setHtml("");
			correct.text = null;
			correctMessage(reaction.envelopeId, correct);
			return;
		}

		// NOTE: doing it this way means no fallback behaviour
		final reactions = [];
		for (areaction => reacts in m.reactions) {
			if (areaction != reaction.key) {
				final react = reacts.find(r -> r.senderId == client.accountId());
				if (react != null && !Std.isOfType(react, CustomEmojiReaction)) {
					reactions.push(react);
				}
			}
		}
		final update = new ReactionUpdate(ID.long(), null, null, m.localId, m.chatId(), client.accountId(), Date.format(std.Date.now()), reactions, EmojiReactions);
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
		markReadUpToMessage(message, () -> {
			// Only send markers for others messages,
			// it's obvious we've read our own
			if (message.isIncoming() && message.localId != null) {
				for (recipient in getParticipants()) {
					// TODO: extended addressing when relevant
					final stanza = new Stanza("message", { to: recipient, id: ID.long() })
						.tag("displayed", { xmlns: "urn:xmpp:chat-markers:0", id: message.localId }).up();
					if (message.threadId != null) {
						stanza.textTag("thread", message.threadId);
					}
					client.sendStanza(stanza);
				}
			}

			publishMds();
			client.trigger("chats/update", [this]);
		});
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function bookmark() {
		final attr: DynamicAccess<String> = { jid: chatId };
		if (displayName != null && displayName != "" && displayName != chatId) {
			attr["name"] = displayName;
		}
		stream.sendIq(
			new Stanza("iq", { type: "set" })
				.tag("query", { xmlns: "jabber:iq:roster" })
				.tag("item", attr)
				.up().up(),
			(response) -> {
				if (response.attr.get("type") == "error") return;
				stream.sendStanza(new Stanza("presence", { to: chatId, type: "subscribe", id: ID.short() }));
				if (isTrusted()) stream.sendStanza(new Stanza("presence", { to: chatId, type: "subscribed", id: ID.short() }));
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
		persistence.storeChats(client.accountId(), [this]);
		if (!isBlocked) sendChatState("gone", null);
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
	private var sync = null;
	private var forceLive = false;
	private var _nickInUse = null;

	@:allow(snikket)
	private function new(client:Client, stream:GenericStream, persistence:Persistence, chatId:String, uiState = Open, isBlocked = false, extensions = null, readUpToId = null, readUpToBy = null, ?disco: Caps) {
		super(client, stream, persistence, chatId, uiState, isBlocked, extensions, readUpToId, readUpToBy);
		if (disco != null) {
			this.disco = disco;
			if (!disco.features.contains("http://jabber.org/protocol/muc")) {
				// Not a MUC, what kind of channel is this?
				forceLive = true;
			}
		}
	}

	@:allow(snikket)
	private function selfPing(refresh: Bool) {
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

		(refresh ? refreshDisco : (cb)->cb())(() -> {
			if (!disco.features.contains("http://jabber.org/protocol/muc")) {
				// Not a MUC, owhat kind of channel is this?
				forceLive = true;
				return;
			}
			stream.sendIq(
				new Stanza("iq", { type: "get", to: getFullJid().asString() })
					.tag("ping", { xmlns: "urn:xmpp:ping" }).up(),
				(response) -> {
					if (response.attr.get("type") == "error") {
						final err = response.getChild("error")?.getChild(null, "urn:ietf:params:xml:ns:xmpp-stanzas");
						if (err.name == "service-unavailable" || err.name == "feature-not-implemented") return selfPingSuccess(); // Error, success!
						if (err.name == "remote-server-not-found" || err.name == "remote-server-timeout") return selfPingSuccess(); // Timeout, retry later
						if (err.name == "item-not-found") return selfPingSuccess(); // Nick was changed?
						trace("SYNC: self-ping fail, join", chatId);
						join();
					} else {
						selfPingSuccess();
					}
				}
			);
		});
	}

	@:allow(snikket)
	private function join() {
		presence = []; // About to ask for a fresh set
		_nickInUse = null;
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
		persistence.lastId(client.accountId(), chatId, doSync);
	}

	private function selfPingSuccess() {
		if (nickInUse() != client.displayName()) {
			final desiredFullJid = JID.parse(chatId).withResource(client.displayName());
			client.sendPresence(desiredFullJid.asString());
		}
		// We did a self ping to see if we were in the room and found we are
		// But we may have missed messages if we were disconnected in the middle
		inSync = false;
		persistence.lastId(client.accountId(), chatId, doSync);
	}

	override public function setPresence(resource:String, presence:Presence) {
		final oneTen = presence?.mucUser?.allTags("status").find((status) -> status.attr.get("code") == "110");
		if (oneTen != null) {
			_nickInUse = resource;
		} else if (resource == _nickInUse) {
			_nickInUse = null;
		}
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
		if (oneTen != null && tripleThree != null) {
			selfPing(true);
		}
	}

	private function doSync(lastId: Null<String>) {
		if (!disco.features.contains("urn:xmpp:mam:2")) {
			inSync = true;
			return;
		}
		if (sync != null) return;

		var threeDaysAgo = Date.format(
			DateTools.delta(std.Date.now(), DateTools.days(-3))
		);
		sync = new MessageSync(
			client,
			stream,
			lastId == null ? { startTime: threeDaysAgo } : { page: { after: lastId } },
			chatId
		);
		sync.setNewestPageFirst(false);
		sync.addContext((builder, stanza) -> {
			builder = prepareIncomingMessage(builder, stanza);
			builder.syncPoint = true;
			return builder;
		});
		final chatMessages = [];
		sync.onMessages((messageList) -> {
			final promises = [];
			final pageChatMessages = [];
			for (m in messageList.messages) {
				switch (m) {
					case ChatMessageStanza(message):
						for (hash in message.inlineHashReferences()) {
							client.fetchMediaByHash([hash], [message.from]);
						}
						pageChatMessages.push(message);
					case ReactionUpdateStanza(update):
						promises.push(new thenshim.Promise((resolve, reject) -> {
							persistence.storeReaction(client.accountId(), update, (_) -> resolve(null));
						}));
					case ModerateMessageStanza(action):
						promises.push(new thenshim.Promise((resolve, reject) -> {
							client.moderateMessage(action).then((_) -> resolve(null));
						}));
					default:
						// ignore
				}
			}
			promises.push(new thenshim.Promise((resolve, reject) -> {
				client.storeMessages(pageChatMessages, resolve);
			}));
			thenshim.PromiseTools.all(promises).then((stored) -> {
				for (messages in stored) {
					if (messages != null) {
						for (message in messages) {
							client.notifySyncMessageHandlers(message);
							if (message != null && message.chatId() == chatId) chatMessages.push(message);
							if (chatMessages.length > 1000) chatMessages.shift(); // Save some RAM
						}
					}
				}
				if (sync.hasMore()) {
					sync.fetchNext();
				} else {
					inSync = true;
					sync = null;
					final lastFromSync = chatMessages[chatMessages.length - 1];
					if (lastFromSync != null && (lastMessageTimestamp() == null || Reflect.compare(lastFromSync.timestamp, lastMessageTimestamp()) > 0)) {
						setLastMessage(lastFromSync);
						client.sortChats();
					}
					final serverIds: Map<String, Bool> = [];
					final dedupedMessages = [];
					chatMessages.reverse();
					for (m in chatMessages) {
						if (!(serverIds[m.serverId] ?? false)) {
							dedupedMessages.unshift(m);
							serverIds[m.serverId] = true;
						}
					}
					final readIndex = dedupedMessages.findIndex((m) -> m.serverId == readUpTo() || !m.isIncoming());
					if (readIndex < 0) {
						setUnreadCount(unreadCount() + dedupedMessages.length);
					} else {
						setUnreadCount(dedupedMessages.length - readIndex - 1);
					}
					client.trigger("chats/update", [this]);
				}
			});
		});
		sync.onError((stanza) -> {
			sync = null;
			if (lastId != null) {
				// Gap in sync, out newest message has expired from server
				doSync(null);
			} else {
				trace("SYNC failed", chatId, stanza);
			}
		});
		sync.fetchNext();
	}

	override public function isTrusted() {
		return uiState != Closed;
	}

	public function isPrivate() {
		return disco.features.contains("muc_membersonly");
	}

	@:allow(snikket)
	private function refreshDisco(?callback: ()->Void) {
		final discoGet = new DiscoInfoGet(chatId);
		discoGet.onFinished(() -> {
			if (discoGet.getResult() != null) {
				final setupNotifications = disco == null && notificationSettings == null;
				disco = discoGet.getResult();
				if (setupNotifications && !isPrivate()) notificationSettings = { mention: true, reply: false };
				persistence.storeCaps(discoGet.getResult());
				persistence.storeChats(client.accountId(), [this]);
			}
			if (callback != null) callback();
		});
		client.sendQuery(discoGet);
	}

	override public function preview() {
		if (lastMessage == null) return super.preview();

		return getParticipantDetails(lastMessage.senderId).displayName + ": " + super.preview();
	}

	@:allow(snikket)
	override private function livePresence() {
		if (forceLive) return true;

		return _nickInUse != null;
	}

	override public function syncing() {
		return !inSync || !livePresence();
	}

	override public function canAudioCall():Bool {
		return disco?.features?.contains("urn:xmpp:jingle:apps:rtp:audio") ?? false;
	}

	override public function canVideoCall():Bool {
		return disco?.features?.contains("urn:xmpp:jingle:apps:rtp:video") ?? false;
	}

	private function nickInUse() {
		return _nickInUse ?? client.displayName();
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
			return new Participant(client.displayName(), chat.getPhoto(), chat.getPlaceholder(), true);
		} else {
			final nick = JID.parse(participantId).resource;
			final placeholderUri = Color.defaultPhoto(participantId, nick == null ? " " : nick.charAt(0));
			return new Participant(nick, null, placeholderUri, false);
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
				sync.addContext((builder, stanza) -> {
					builder = prepareIncomingMessage(builder, stanza);
					builder.syncPoint = false;
					return builder;
				});
				fetchFromSync(sync, handler);
			}
		});
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getMessagesAfter(afterId:Null<String>, afterTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void {
		if (afterId == lastMessageId() && !syncing()) {
			handler([]);
			return;
		}
		persistence.getMessagesAfter(client.accountId(), chatId, afterId, afterTime, (messages) -> {
			if (messages.length > 0) {
				handler(messages);
			} else {
				var filter:MAMQueryParams = {};
				if (afterId != null) filter.page = { after: afterId };
				var sync = new MessageSync(this.client, this.stream, filter, chatId);
				sync.addContext((builder, stanza) -> {
					builder = prepareIncomingMessage(builder, stanza);
					builder.syncPoint = false;
					return builder;
				});
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
	private function prepareIncomingMessage(message:ChatMessageBuilder, stanza:Stanza) {
		message.syncPoint = !syncing();
		if (message.type == MessageChat) message.type = MessageChannelPrivate;
		message.senderId = stanza.attr.get("from"); // MUC always needs full JIDs
		if (message.senderId == getFullJid().asString()) {
			message.recipients = message.replyTo;
			message.direction = MessageSent;
		}
		return message;
	}

	private function prepareOutgoingMessage(message:ChatMessageBuilder) {
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
	public function correctMessage(localId:String, message:ChatMessageBuilder) {
		final toSendId = message.localId;
		message = prepareOutgoingMessage(message);
		message.versions = [message.build()]; // This is a correction
		message.localId = localId;
		client.storeMessages([message.build()], (corrected) -> {
			message.versions = corrected[0].localId == localId ? cast corrected[0].versions : [message.build()];
			message.localId = toSendId;
			client.sendStanza(message.build().asStanza());
			client.notifyMessageHandlers(corrected[0], CorrectionEvent);
			if (localId == lastMessage?.localId) {
				setLastMessage(corrected[0]);
				client.trigger("chats/update", [this]);
			}
		});
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function sendMessage(message:ChatMessageBuilder):Void {
		if (typingTimer != null) typingTimer.stop();
		client.chatActivity(this);
		message = prepareOutgoingMessage(message);
		final stanza = message.build().asStanza();
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
				client.storeMessages([message.build()], (stored) -> {
					client.sendStanza(stanza);
					setLastMessage(stored[0]);
					client.notifyMessageHandlers(stored[0], stored[0].versions.length > 1 ? CorrectionEvent : DeliveryEvent);
					client.trigger("chats/update", [this]);
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
	public function removeReaction(m:ChatMessage, reaction:Reaction) {
		if (Std.isOfType(reaction, CustomEmojiReaction)) {
			if (reaction.envelopeId == null) throw "Cannot remove custom emoji reaction without envelopeId";
			final correct = m.reply();
			correct.localId = ID.long();
			correct.setHtml("");
			correct.text = null;
			correctMessage(reaction.envelopeId, correct);
			return;
		}

		// NOTE: doing it this way means no fallback behaviour
		final reactions = [];
		for (areaction => reacts in m.reactions) {
			if (areaction != reaction.key) {
				final react = reacts.find(r -> r.senderId == getFullJid().asString());
				if (react != null && !Std.isOfType(react, CustomEmojiReaction)) reactions.push(react);
			}
		}
		final update = new ReactionUpdate(ID.long(), m.serverId, m.chatId(), null, m.chatId(), getFullJid().asString(), Date.format(std.Date.now()), reactions, EmojiReactions);
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
		markReadUpToMessage(message, () -> {
			final stanza = new Stanza("message", { to: chatId, id: ID.long(), type: "groupchat" })
				.tag("displayed", { xmlns: "urn:xmpp:chat-markers:0", id: message.serverId }).up();
			if (message.threadId != null) {
				stanza.textTag("thread", message.threadId);
			}
			client.sendStanza(stanza);

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
		persistence.storeChats(client.accountId(), [this]);
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
	public final notificationsFiltered: Null<Bool>;
	public final notifyMention: Bool;
	public final notifyReply: Bool;

	public function new(chatId: String, trusted: Bool, avatarSha1: Null<BytesData>, presence: Map<String, Presence>, displayName: Null<String>, uiState: Null<UiState>, isBlocked: Null<Bool>, extensions: Null<String>, readUpToId: Null<String>, readUpToBy: Null<String>, notificationsFiltered: Null<Bool>, notifyMention: Bool, notifyReply: Bool, disco: Null<Caps>, klass: String) {
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
		this.notificationsFiltered = notificationsFiltered;
		this.notifyMention = notifyMention;
		this.notifyReply = notifyReply;
		this.disco = disco;
		this.klass = klass;
	}

	public function toChat(client: Client, stream: GenericStream, persistence: Persistence) {
		final extensionsStanza = Stanza.fromXml(Xml.parse(extensions));
		var filterN = notificationsFiltered ?? false;
		var mention = notifyMention;

		final chat = if (klass == "DirectChat") {
			new DirectChat(client, stream, persistence, chatId, uiState, isBlocked, extensionsStanza, readUpToId, readUpToBy);
		} else if (klass == "Channel") {
			final channel = new Channel(client, stream, persistence, chatId, uiState, isBlocked, extensionsStanza, readUpToId, readUpToBy);
			channel.disco = disco ?? new Caps("", [], ["http://jabber.org/protocol/muc"]);
			if (notificationsFiltered == null && !channel.isPrivate()) {
				mention = filterN = true;
			}
			channel;
		} else {
			throw "Unknown class of " + chatId + ": " + klass;
		}
		chat.setNotifications(filterN, mention, notifyReply);
		if (displayName != null) chat.displayName = displayName;
		if (avatarSha1 != null) chat.setAvatarSha1(avatarSha1);
		chat.setTrusted(trusted);
		for (resource => p in presence) {
			chat.setPresence(resource, p);
		}
		return chat;
	}
}
