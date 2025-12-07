package borogove;

import haxe.DynamicAccess;
import haxe.io.Bytes;
import haxe.io.BytesData;
import thenshim.Promise;
import borogove.Chat;
import borogove.ChatMessage;
import borogove.Color;
import borogove.GenericStream;
import borogove.ID;
import borogove.Message;
import borogove.MessageSync;
import borogove.Outbox;
import borogove.Reaction;
#if !NO_JINGLE
import borogove.calls.PeerConnection;
import borogove.calls.Session;
#end
import borogove.queries.DiscoInfoGet;
import borogove.queries.DiscoItemsGet;
import borogove.queries.MAMQuery;
using Lambda;
using StringTools;
using borogove.Util;

#if cpp
import HaxeCBridge;
#end

enum abstract UiState(Int) {
	var Pinned;
	var Open; // or Unspecified
	var Closed; // Archived
	var Invited;
}

enum abstract UserState(Int) {
	var Gone;
	var Inactive;
	var Active;
	var Composing;
	var Paused;
}

// Describes the current encryption mode of the conversation
// This mode is a high-level representation of the user/app *intent*
// for the current conversation - e.g. not a guarantee that incoming
// messages will always match this expectation. It is used to determine
// the logic for outgoing messages, though.
enum abstract EncryptionMode(Int) {
	var Unencrypted; // No end-to-end encryption
	var EncryptedOMEMO; // Use OMEMO
}

#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
abstract class Chat {
	private var client:Client;
	private var stream:GenericStream;
	private var persistence:Persistence;
	@:allow(borogove)
	private var avatarSha1:Null<BytesData> = null;
	@:allow(borogove)
	private var presence:Map<String, Presence> = [];
	private var trusted:Bool = false;
	/**
		ID of this Chat
	**/
	public var chatId(default, null):String;
#if !NO_JINGLE
	@:allow(borogove)
	private var jingleSessions: Map<String, Session> = [];
#end
	@:allow(borogove)
	private var displayName:String;
	/**
		Current state of this chat
	**/
	@:allow(borogove)
	public var uiState(default, null): UiState = Open;
	/**
		Is this chat blocked?
	**/
	public var isBlocked(default, null): Bool = false;
	/**
		The most recent message in this chat
	**/
	public var lastMessage(default, null): Null<ChatMessage>;
	/**
		Has this chat ever been bookmarked?
	**/
	public var isBookmarked(default, null): Bool = false;
	@:allow(borogove)
	private var extensions: Stanza;
	private var _unreadCount = 0;
	private var readUpToId: Null<String>;
	@:allow(borogove)
	private var readUpToBy: Null<String>;
	private var isTyping = false;
	private var typingThread: Null<String> = null;
	private var typingTimer: haxe.Timer = null;
	private var isActive: Null<Bool> = null;
	private var activeThread: Null<String> = null;
	private var notificationSettings: Null<{reply: Bool, mention: Bool}> = null;
	private var outbox = new Outbox();
	private var _encryptionMode: EncryptionMode = Unencrypted;

	@:allow(borogove)
	private var omemoContactDeviceIDs: Null<Array<Int>> = null;

	@:allow(borogove)
	private function new(client:Client, stream:GenericStream, persistence:Persistence, chatId:String, uiState = Open, isBlocked = false, extensions: Null<Stanza> = null, readUpToId: Null<String> = null, readUpToBy: Null<String> = null, omemoContactDeviceIDs: Array<Int> = null) {
		if (chatId == null || chatId == "") {
			throw "chatId may not be empty";
		}
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
		this.omemoContactDeviceIDs = omemoContactDeviceIDs;
	}

	@:allow(borogove)
	abstract private function prepareIncomingMessage(message:ChatMessageBuilder, stanza:Stanza):ChatMessageBuilder;

	/**
		Fetch a page of messages before some point

		@param beforeId id of the message to look before
		@param beforeTime timestamp of the message to look before,
		       String in format YYYY-MM-DDThh:mm:ss[.sss]+00:00
		@returns Promise resolving to an array of ChatMessage that are found
	**/
	abstract public function getMessagesBefore(beforeId:Null<String>, beforeTime:Null<String>):Promise<Array<ChatMessage>>;

	/**
		Fetch a page of messages after some point

		@param afterId id of the message to look after
		@param afterTime timestamp of the message to look after,
		       String in format YYYY-MM-DDThh:mm:ss[.sss]+00:00
		@returns Promise resolving to an array of ChatMessage that are found
	**/
	abstract public function getMessagesAfter(afterId:Null<String>, afterTime:Null<String>):Promise<Array<ChatMessage>>;

	/**
		Fetch a page of messages around (before, including, and after) some point

		@param aroundId id of the message to look around
		@param aroundTime timestamp of the message to look around,
		       String in format YYYY-MM-DDThh:mm:ss[.sss]+00:00
		@returns Promise resolving to an array of ChatMessage that are found
	**/
	abstract public function getMessagesAround(aroundId:Null<String>, aroundTime:Null<String>):Promise<Array<ChatMessage>>;

	private function fetchFromSync(sync: MessageSync): Promise<Array<ChatMessage>> {
		return new thenshim.Promise((resolve, reject) -> {
			sync.onMessages((messageList) -> {
				final chatMessages = [];
				for (m in messageList.messages) {
					switch (m.parsed) {
					case ChatMessageStanza(message):
						chatMessages.push(message);
					case ReactionUpdateStanza(update):
						persistence.storeReaction(client.accountId(), update);
					case ModerateMessageStanza(action):
						client.moderateMessage(action);
					case ErrorMessageStanza(localId, stanza):
						persistence.updateMessageStatus(
							client.accountId(),
							localId,
							MessageFailedToSend,
							stanza.getErrorText(),
						);
					default:
						// ignore
					}
				}
				if (chatMessages.length < 1 && sync.hasMore()) {
					sync.fetchNext();
				} else {
					client.storeMessages(chatMessages).then((chatMessages) -> {
						resolve(chatMessages.filter((m) -> m != null && m.chatId() == chatId));
					});
				}
			});
			sync.onError(reject);
			sync.fetchNext();
		});
	}

	/**
		Send a message to this Chat

		@param message the ChatMessageBuilder to send
	**/
	abstract public function sendMessage(message:ChatMessageBuilder):Void;

	abstract private function sendMessageStanza(stanza: Stanza, ?outboxItem: OutboxItem):Void;

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
				return "";
			},
			(text, uri) -> {
				final hash = Hash.fromUri(uri);
				toSend.setHtml('<img alt="' + Util.xmlEscape(text) + '" src="' + Util.xmlEscape(hash == null ? uri : hash.bobUri()) + '" />');
				return "";
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
		uiState = uiState != Pinned ? Pinned : Open;
		persistence.storeChats(client.accountId(), [this]);
		client.sortChats();
		client.trigger("chats/update", [this]);
	}

	/**
		Block this chat so it will not re-open
	**/
	public function block(reportSpam: Bool = false, spamMessage: Null<ChatMessage> = null, onServer: Bool = true): Void {
		if (reportSpam && !onServer) throw "Can't report SPAM if not sending to server";

		if (onServer && invites().length > 0 && uiState == Invited) {
			// Block inviters instead
			for (invite in invites()) {
				final inviteFrom = JID.parse(invite.attr.get("from"));
				final inviteFromBareChat = client.getChat(inviteFrom.asBare().asString());
				final toBlock = inviteFromBareChat != null && Std.isOfType(inviteFromBareChat, Channel) ? inviteFrom.asString() : inviteFrom.asBare().asString();

				final iq = new Stanza("iq", { type: "set", id: ID.short() })
					.tag("block", { xmlns: "urn:xmpp:blocking" })
					.tag("item", { jid: toBlock });
				if (reportSpam) {
					final report = iq.tag("report", { xmlns: "urn:xmpp:reporting:1", reason: "urn:xmpp:reporting:spam" });
					final stanzaIdEl = invite.getChild("stanza-id", "urn:xmpp:sid:0");
					if (stanzaIdEl != null) report.addChild(stanzaIdEl);
					report.up();
				}
				stream.sendIq(iq, (response) -> {});
			}
			close();
			return;
		}

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
			if (reportSpam) {
				final report = iq.tag("report", { xmlns: "urn:xmpp:reporting:1", reason: "urn:xmpp:reporting:spam" });
				if (spamMessage != null) {
					report.tag("stanza-id", { xmlns: "urn:xmpp:sid:0", by: spamMessage.serverIdBy, id: spamMessage.serverId }).up();
				} else {
					for (invite in invites()) {
						final stanzaIdEl = invite.getChild("stanza-id", "urn:xmpp:sid:0");
						if (stanzaIdEl != null) report.addChild(stanzaIdEl);
					}
				}
				report.up();
			}
			stream.sendIq(iq, (response) -> {});
		}
	}

	/**
		Unblock this chat so it will open again
	**/
	public function unblock(onServer: Bool = true): Void {
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

	@:allow(borogove)
	private function setNotificationsInternal(filtered: Bool, mention: Bool, reply: Bool) {
		if (filtered) {
			notificationSettings = { mention: mention, reply: reply };
		} else {
			notificationSettings = null;
		}
	}

	/**
		Update notification preferences
	**/
	public function setNotifications(filtered: Bool, mention: Bool, reply: Bool) {
		setNotificationsInternal(filtered, mention, reply);
		persistence.storeChats(client.accountId(), [this]);
		client.trigger("chats/update", [this]);
		client.updatePushIfEnabled();
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

	@:allow(borogove)
	private function updateFromBookmark(item: Stanza) {
		isBookmarked = true;
		final conf = item.getChild("conference", "urn:xmpp:bookmarks:1");
		final fn = conf.attr.get("name");
		if (fn != null) displayName = fn;
		uiState = (conf.attr.get("autojoin") == "1" || conf.attr.get("autojoin") == "true") ? (uiState == Pinned ? Pinned : Open) : Closed;
		extensions = conf.getChild("extensions") ?? new Stanza("extensions", { xmlns: "urn:xmpp:bookmarks:1" });
	}

	@:allow(borogove)
	private function updateFromRoster(item: { fn: Null<String>, subscription: String }) {
		isBookmarked = true;
		setTrusted(item.subscription == "both" || item.subscription == "from");
		if (item.fn != null && item.fn != "") displayName = item.fn;
		if (uiState == Invited) uiState = Open;
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

	@:allow(borogove)
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

	@:allow(borogove)
	private function setLastMessage(message:Null<ChatMessage>) {
		lastMessage = message;
	}

	/**
		Set the display name to use for this chat

		@param displayName String to use as display name
	**/
	public function setDisplayName(displayName: String) {
		this.displayName = displayName;
		bookmark();
	}

	/**
		The display name of this Chat
	**/
	public function getDisplayName() {
		if (this.displayName == chatId) {
			if (chatId == client.accountId()) return client.displayName();

			final participants = getParticipants();
			if (participants.length > 2 && participants.length < 20) {
				return participants.map(id -> {
					final p = id == chatId ? null : getParticipantDetails(id);
					p == null || p.isSelf ? null : p.displayName;
				}).filter(fn -> fn != null).join(", ");
			}
		} else if (uiState == Invited) {
			return '${displayName} (${chatId})';
		}

		return displayName;
	}

	@:allow(borogove)
	private function setPresence(resource:String, presence:Presence) {
		this.presence.set(resource, presence);
	}

	@:allow(borogove)
	private function setCaps(resource:String, caps:Caps) {
		final presence = presence.get(resource);
		if (presence != null) {
			presence.caps = caps;
			setPresence(resource, presence);
		} else {
			setPresence(resource, new Presence(caps, null, null));
		}
	}

	@:allow(borogove)
	private function removePresence(resource:String) {
		presence.remove(resource);
	}

	@:allow(borogove)
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

	@:allow(borogove)
	private function getResourceCaps(resource:String):Caps {
		return presence[resource]?.caps ?? new Caps("", [], [], []);
	}

	@:allow(borogove)
	private function setAvatarSha1(sha1: BytesData) {
		this.avatarSha1 = sha1;
	}

	/**
		Set if this chat is to be trusted with our presence, etc

		@param trusted Bool if trusted or not
	**/
	public function setTrusted(trusted:Bool) {
		this.trusted = trusted;
		if (trusted && uiState == Invited) {
			uiState = Open;
			client.trigger("chats/update", [this]);
		}
	}

	/**
		Is this a chat with an entity we trust to see our online status?
	**/
	public function isTrusted():Bool {
		return this.trusted || chatId == client.accountId();
	}

	@:allow(borogove)
	private function livePresence() {
		return true;
	}

	/**
		@returns if this chat is currently syncing with the server
	**/
	public function syncing() {
		return !client.inSync;
	}

	/**
		Can audio calls be started in this Chat?
	**/
	public function canAudioCall():Bool {
#if !NO_JINGLE
		for (resource => p in presence) {
			if (p.caps?.features?.contains("urn:xmpp:jingle:apps:rtp:audio") ?? false) return true;
		}
#end
		return false;
	}

	/**
		Can video calls be started in this Chat?
	**/
	public function canVideoCall():Bool {
#if !NO_JINGLE
		for (resource => p in presence) {
			if (p.caps?.features?.contains("urn:xmpp:jingle:apps:rtp:video") ?? false) return true;
		}
#end
		return false;
	}

#if !NO_JINGLE
	/**
		Start a new call in this Chat

		@param audio do we want audio in this call
		@param video do we want video in this call
	**/
	public function startCall(audio: Bool, video: Bool) {
		if (uiState == Invited) uiState = Open;
		final session = new OutgoingProposedSession(client, JID.parse(chatId));
		jingleSessions.set(session.sid, session);
		session.propose(audio, video);
		return session;
	}

	@HaxeCBridge.noemit
	public function addMedia(streams: Array<MediaStream>) {
		if (callStatus() != Ongoing) throw "cannot add media when no call ongoing";
		jingleSessions.iterator().next().addMedia(streams);
	}

	/**
		Accept any incoming calls in this Chat
	**/
	public function acceptCall() {
		if (uiState == Invited) uiState = Open;
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

		return NoCall;
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
#end
	/**
		Get encryption mode for this chat
	**/
	public function encryptionMode(): String {
		switch(_encryptionMode) {
			case Unencrypted:
				return "unencrypted";
			case EncryptedOMEMO:
				return "omemo";
		}
	}

	/**
		Can the user send messages to this chat?
	**/
	public function canSend() {
		return Caps.withFeature(getCaps(), "urn:xmpp:noreply:0").length < 1;
	}

	/**
		Invite another chat's participants to participate in this one
	**/
	public function invite(other: Chat, threadId: Null<String> = null) {
		final attr: DynamicAccess<String> = {
			xmlns: "jabber:x:conference",
			jid: chatId
		};
		if (threadId != null) {
			attr.set("continue", "true");
			attr.set("thread", threadId);
		}
		other.sendMessageStanza(
			new Stanza("message").tag("x", attr).up()
		);
	}

	/**
		Can the user invite others to this chat?
	**/
	public function canInvite() {
		return false;
	}

	/**
		This chat's primary mode of interaction is via commands
	**/
	public function isApp() {
		if ({ iterator: getCaps }.array().length < 1) {
			// No caps so let's guess that domains are apps
			return chatId.indexOf("@") < 0 && hasCommands();
		}

		final bot = Caps.withIdentity(getCaps(), "client", "bot").length > 0;
		final client = Caps.withIdentity(getCaps(), "client", null).length > 0;
		final account = Caps.withIdentity(getCaps(), "account", null).length > 0;
		// Clients are not apps, we chat with them
		if ((client || account) && !bot) return false;

		final noReply = Caps.withFeature(getCaps(), "urn:xmpp:noreply:0").length > 0;
		// A bot that doesn't want messages is an app
		if (bot && noReply) return hasCommands();

		final conference = Caps.withIdentity(getCaps(), "conference", null).length > 0;
		// A MUC component is an app
		if (conference && chatId.indexOf("@") < 0) return hasCommands();

		// If it's not a client or conference, guess it's an app
		return !client && !conference && hasCommands();
	}

	/**
		Does this chat provide a menu of commands?
	**/
	public function hasCommands() {
		return commandJids().length > 0;
	}

	public function commands(): Promise<Array<Command>> {
		return thenshim.PromiseTools.all(commandJids().map(jid -> new Promise((resolve, reject) -> {
			final itemsGet = new DiscoItemsGet(jid.asString(), "http://jabber.org/protocol/commands");
			itemsGet.onFinished(() -> {
				final bareJid = jid.asBare();
				resolve((itemsGet.getResult() ?? []).filter(item ->
					// Remove advertisement of commands at other JIDs for now
					// It's a potential security/privacy issue depending on UX
					item.jid != null && item.jid.asBare().equals(jid) && item.node != null
				).map(item -> new Command(client, item)));
			});
			client.sendQuery(itemsGet);
		}))).then(commands -> commands.flatten());
	}

	private function commandJids() {
		final jids = [];
		final jid = JID.parse(chatId);
		for (resource in Caps.withFeature(getCaps(), "http://jabber.org/protocol/commands")) {
			jids.push(resource == "" || resource == null ? jid : jid.withResource(resource));
		}
		if (jids.length < 1 && jid.isDomain()) {
			jids.push(jid);
		}
		return jids;
	}

	/**
		The Participant that originally invited us to this Chat, if we were invited
	**/
	public function invitedBy() {
		final inviteEls = invites();
		if (inviteEls.length < 1) return null;

		final inviteFrom = JID.parse(inviteEls[0].attr.get("from"));
		final bare = inviteFrom.asBare().asString();
		final maybeChannel = client.getChat(bare);
		if (maybeChannel != null) {
			final channel = maybeChannel.downcast(Channel);
			if (channel != null) {
				return channel.getParticipantDetails(inviteFrom.asString());
			}
		}

		return (maybeChannel ?? client.getDirectChat(bare)).getParticipantDetails(bare);
	}

	private function invites() {
		return extensions.allTags("invite", "http://jabber.org/protocol/muc#user");
	}

	private function recomputeUnread(): Promise<Any> {
		return persistence.getMessagesBefore(client.accountId(), chatId, null, null).then((messages) -> {
			var i = messages.length;
			while (--i >= 0) {
				if (messages[i].serverId == readUpToId || !messages[i].isIncoming()) break;
			}
			setUnreadCount(messages.length - (i + 1));
		});
	}

	@:allow(borogove)
	private function markReadUpToId(upTo: String, upToBy: String): Promise<Any> {
		if (upTo == null) return Promise.reject(null);
		if (readUpTo() == upTo) return Promise.reject(null);

		readUpToId = upTo;
		readUpToBy = upToBy;
		persistence.storeChats(client.accountId(), [this]);
		return recomputeUnread();
	}

	private function markReadUpToMessage(message: ChatMessage): Promise<Any> {
		if (message.serverId == null || message.chatId() != chatId) return Promise.reject(null);
		if (readUpTo() == message.serverId) return Promise.reject(null);

		if (readUpTo() == null) {
			return markReadUpToId(message.serverId, message.serverIdBy);
		}

		return persistence.getMessage(client.accountId(), chatId, readUpTo(), null).then((readMessage) -> {
			if (readMessage != null && Reflect.compare(message.timestamp, readMessage.timestamp) <= 0) {
				return Promise.reject(null);
			}

			return markReadUpToId(message.serverId, message.serverIdBy);
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
	@:allow(borogove)
	private function new(client:Client, stream:GenericStream, persistence:Persistence, chatId:String, uiState = Open, isBlocked = false, extensions: Null<Stanza> = null, readUpToId: Null<String> = null, readUpToBy: Null<String> = null, omemoContactDeviceIDs: Array<Int> = null) {
		super(client, stream, persistence, chatId, uiState, isBlocked, extensions, readUpToId, readUpToBy, omemoContactDeviceIDs);
		outbox.start();
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getParticipants(): Array<String> {
		final counters = counterparts();
		final ids: Map<String, Bool> = [];
		if (counters.length < 2 && (lastMessage?.recipients?.length ?? 0) > 1) {
			ids[lastMessage.senderId] = true;
			for (id in lastMessage.recipients.map(r -> r.asString())) {
				ids[id] = true;
			}
		} else {
			ids[client.accountId()] = true;
			for (id in counterparts()) {
				ids[id] = true;
			}
		}
		return { iterator: () -> ids.keys() }.array();
	}

	private function counterparts() {
		return chatId.split("\n");
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getParticipantDetails(participantId:String): Participant {
		final chat = client.getDirectChat(participantId);
		return new Participant(chat.getDisplayName(), chat.getPhoto(), chat.getPlaceholder(), chat.chatId == client.accountId(), JID.parse(participantId));
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getMessagesBefore(beforeId:Null<String>, beforeTime:Null<String>):Promise<Array<ChatMessage>> {
		return persistence.getMessagesBefore(client.accountId(), chatId, beforeId, beforeTime).then((messages) ->
			if (messages.length > 0) {
				Promise.resolve(messages);
			} else {
				var filter:MAMQueryParams = { with: this.chatId };
				if (beforeId != null) filter.page = { before: beforeId };
				var sync  = new MessageSync(this.client, this.stream, filter);
				fetchFromSync(sync);
			}
		);
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getMessagesAfter(afterId:Null<String>, afterTime:Null<String>):Promise<Array<ChatMessage>> {
		if (afterId == lastMessageId() && !syncing()) {
			return Promise.resolve([]);
		}
		return persistence.getMessagesAfter(client.accountId(), chatId, afterId, afterTime).then((messages) ->
			if (messages.length > 0) {
				Promise.resolve(messages);
			} else {
				var filter:MAMQueryParams = { with: this.chatId };
				if (afterId != null) filter.page = { after: afterId };
				var sync  = new MessageSync(this.client, this.stream, filter);
				fetchFromSync(sync);
			}
		);
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getMessagesAround(aroundId:Null<String>, aroundTime:Null<String>):Promise<Array<ChatMessage>> {
		// TODO: fetch more from MAM if nothing locally?
		return persistence.getMessagesAround(client.accountId(), chatId, aroundId, aroundTime);
	}

	@:allow(borogove)
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
		message.recipients = counterparts().map((p) -> JID.parse(p));
		message.to = message.recipients[0];
		return message;
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function correctMessage(localId:String, message:ChatMessageBuilder) {
		final toSendId = message.localId;
		message = prepareOutgoingMessage(message);
		message.versions = [message.build()]; // This is a correction
		message.localId = localId;
		final outboxItem = outbox.newItem();
		client.storeMessages([message.build()]).then((corrected) -> {
			message.versions = corrected[0].versions[corrected[0].versions.length - 1]?.localId == localId ? cast corrected[0].versions : [message.build()];
			message.localId = toSendId;
			sendMessageStanza(message.build().asStanza(), outboxItem);
			if (localId == lastMessage?.localId) {
				setLastMessage(corrected[0]);
				client.trigger("chats/update", [this]);
			}
			client.notifyMessageHandlers(corrected[0], CorrectionEvent);
		});
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function sendMessage(message: ChatMessageBuilder):Void {
		if (uiState == Invited) uiState = Open;
		if (typingTimer != null) typingTimer.stop();
		client.chatActivity(this);
		message = prepareOutgoingMessage(message);
		message.to = message.recipients[0]; // Just pick one for the stanza we re-parse
		final fromStanza = Message.fromStanza(message.build().asStanza(), client.jid).parsed;
		switch (fromStanza) {
			case ChatMessageStanza(_):
				final outboxItem = outbox.newItem();
				client.storeMessages([message.build()]).then((stored) -> {
					final stanza = message.build().asStanza();
					if (isActive != null) {
						isActive = true;
						activeThread = message.threadId;
						stanza.tag("active", { xmlns: "http://jabber.org/protocol/chatstates" }).up();
					}
					sendMessageStanza(stanza, outboxItem);
					setLastMessage(message.build());
					client.notifyMessageHandlers(stored[0], stored[0].versions.length > 1 ? CorrectionEvent : DeliveryEvent);
					client.trigger("chats/update", [this]);
				});
			case ReactionUpdateStanza(update):
				persistence.storeReaction(client.accountId(), update).then((stored) -> {
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
		final outboxItem = outbox.newItem();
		persistence.storeReaction(client.accountId(), update).then((stored) -> {
			sendMessageStanza(update.asStanza(), outboxItem);
			if (stored != null) client.notifyMessageHandlers(stored, ReactionEvent);
		});
	}

	private function sendMessageStanza(stanza: Stanza, ?outboxItem: OutboxItem) {
		if (stanza.name != "message") throw "Can only send message stanza this way";

		if (outboxItem == null) outboxItem = outbox.newItem();

		final counters = counterparts();
		thenshim.PromiseTools.all(counters.map(counterpart -> {
			final clone = stanza.clone();
			clone.attr.set("to", counterpart);
			if (counters.length > 1 && stanza.getChild("addresses", "http://jabber.org/protocol/address") == null) {
				final addresses = clone.tag("addresses", { xmlns: "http://jabber.org/protocol/address" });
				for (counter in counters) {
					addresses.tag("address", { type: "to", jid: counter, delivered: "true" }).up();
				}
				addresses.up();
			}

			#if NO_OMEMO
			return Promise.resolve(stanza);
			#else
			return client.omemo.encryptMessage(JID.parse(counterpart), stanza).then((encryptedStanza) -> {
				return Promise.resolve(stanza);
			});
			#end
		})).then(stanzas -> {
			outboxItem.handle(() -> {
				for (stanza in stanzas) {
					client.sendStanza(stanza);
				}
			});
		});
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function lastMessageId() {
		return lastMessage?.serverId ?? lastMessage?.localId;
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function markReadUpTo(message: ChatMessage) {
		markReadUpToMessage(message).then(_ -> {
			// Only send markers for others messages,
			// it's obvious we've read our own
			if (message.isIncoming() && message.localId != null) {
				for (recipient in counterparts()) {
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
			return;
		}, e -> e != null ? Promise.reject(e) : null);
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function bookmark() {
		isBookmarked = true;
		if (uiState == Invited) {
			uiState = Open;
			client.trigger("chats/update", [this]);
		}
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
		if (!isTrusted()) return;

		for (recipient in counterparts()) {
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
		if (uiState == Invited) {
			client.sendStanza(new Stanza("presence", { to: chatId, type: "unsubscribed", id: ID.short() }));
		}
		// Should this remove from roster? Or set untrusted?
		uiState = Closed;
		persistence.storeChats(client.accountId(), [this]);
		if (!isBlocked) sendChatState("gone", null);
		client.trigger("chats/update", [this]);
		client.sortChats();
	}
}

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Channel extends Chat {
	@:allow(borogove)
	private var disco: Caps = new Caps("", [], ["http://jabber.org/protocol/muc"], []);
	private var inSync = true;
	private var sync = null;
	private var forceLive = false;
	private var _nickInUse = null;

	@:allow(borogove)
	private function new(client:Client, stream:GenericStream, persistence:Persistence, chatId:String, uiState = Open, isBlocked = false, extensions = null, readUpToId = null, readUpToBy = null, ?disco: Caps) {
		super(client, stream, persistence, chatId, uiState, isBlocked, extensions, readUpToId, readUpToBy);
		if (disco != null) {
			this.disco = disco;
			if (!disco.features.contains("http://jabber.org/protocol/muc")) {
				// Not a MUC, what kind of channel is this?
				forceLive = true;
				outbox.start();
			}
		}
	}

	@:allow(borogove)
	private function selfPing(refresh: Bool) {
		if (uiState == Invited) return;

		if (uiState == Closed) {
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
				outbox.start();
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

	@:allow(borogove)
	private function join() {
		if (uiState == Invited || uiState == Closed) {
			// Do not join
			return;
		}

		presence = []; // About to ask for a fresh set
		_nickInUse = null;
		outbox.pause();
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
		persistence.lastId(client.accountId(), chatId).then(doSync);
	}

	private function selfPingSuccess() {
		if (nickInUse() != client.displayName()) {
			final desiredFullJid = JID.parse(chatId).withResource(client.displayName());
			client.sendPresence(desiredFullJid.asString());
		}
		// We did a self ping to see if we were in the room and found we are
		// But we may have missed messages if we were disconnected in the middle
		inSync = false;
		persistence.lastId(client.accountId(), chatId).then(doSync);
	}

	override public function getDisplayName() {
		if (this.displayName == chatId) {
			final title = (info()?.field("muc#roomconfig_roomname")?.value ?? []).join("\n");
			if (title != null && title != "") return title;
		}

		return super.getDisplayName();
	}

	public function description() {
		return (info()?.field("muc#roominfo_description")?.value ?? []).join("\n");
	}

	private function info() {
		return disco?.data?.find(d -> d.field("FORM_TYPE")?.value?.at(0) == "http://jabber.org/protocol/muc#roominfo");
	}


	override public function invite(chat: Chat, threadId: Null<String> = null) {
		if (isPrivate()) {
			client.sendStanza(
				new Stanza("iq", { to: chatId })
					.tag("query", { xmlns: "http://jabber.org/protocol/muc#admin" })
					.tag("item", { affiliation: "member", jid: chat.chatId })
					.up().up()
			);
		}

		super.invite(chat, threadId);
	}

	override public function canInvite() {
		if (!isPrivate()) return true;
		if (_nickInUse == null) return false;

		final p = presence[_nickInUse];
		if (p == null) return false;

		if (p.mucUser.role == "moderator") return true;

		return false;
	}

	override public function canSend() {
		if (!super.canSend()) return false;
		if (_nickInUse == null) return true;

		final p = presence[_nickInUse];
		if (p == null) return true;

		return p.mucUser.role != "visitor";
	}

	@:allow(borogove)
	override private function getCaps():KeyValueIterator<String, Caps> {
		return ["" => disco].keyValueIterator();
	}

	@:allow(borogove)
	override private function setPresence(resource:String, presence:Presence) {
		final oneTen = presence?.mucUser?.statusCodes?.find((status) -> status == "110");
		if (oneTen != null) {
			_nickInUse = resource;
			outbox.start();
		} else if (resource == _nickInUse) {
			_nickInUse = null;
			outbox.pause();
		}
		if (presence != null && presence.mucUser != null && oneTen == null) {
			final existing = this.presence.get(resource);
			if (existing != null && existing?.mucUser?.statusCodes?.find((status) -> status == "110") != null) {
				final mucUser: Stanza = presence.mucUser;
				mucUser.tag("status", { code: "110" }).up();
				setPresence(resource, presence);
				return;
			}
		}
		super.setPresence(resource, presence);
		final tripleThree = presence?.mucUser?.statusCodes?.find((status) -> status == "333");
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
				switch (m.parsed) {
					case ChatMessageStanza(message):
						for (hash in message.inlineHashReferences()) {
							client.fetchMediaByHash([hash], [message.from]);
						}
						pageChatMessages.push(message);
					case ReactionUpdateStanza(update):
						promises.push(
							persistence.storeReaction(client.accountId(), update).then(_ -> null)
						);
					case ModerateMessageStanza(action):
						promises.push(new thenshim.Promise((resolve, reject) -> {
							client.moderateMessage(action).then((_) -> resolve(null));
						}));
					case ErrorMessageStanza(localId, stanza):
						promises.push(persistence.updateMessageStatus(
							client.accountId(),
							localId,
							MessageFailedToSend,
							stanza.getErrorText(),
						).then(m -> [m], _ -> []));
					default:
						// ignore
				}
			}
			promises.push(client.storeMessages(pageChatMessages));
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

					final serverIds: Map<String, Bool> = [];
					final dedupedMessages = [];
					chatMessages.reverse();
					for (m in chatMessages) {
						if (!(serverIds[m.serverId] ?? false)) {
							dedupedMessages.unshift(m);
							serverIds[m.serverId] = true;
						}
					}

					// Sort by time so that eg edits go into the past
					dedupedMessages.sort((x, y) -> Reflect.compare(x.timestamp, y.timestamp));

					final lastFromSync = dedupedMessages[dedupedMessages.length - 1];
					if (lastFromSync != null && (lastMessage?.timestamp == null || Reflect.compare(lastFromSync.timestamp, lastMessage?.timestamp) > 0)) {
						setLastMessage(lastFromSync);
						client.sortChats();
					}

					final readIndex = dedupedMessages.findLastIndex((m) -> m.serverId == readUpTo() || !m.isIncoming());
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

	override public function setTrusted(trusted: Bool) {
		super.setTrusted(trusted);
		if (trusted) selfPing(true);
	}

	override public function isTrusted() {
		return uiState != Closed && uiState != Invited;
	}

	public function isPrivate() {
		return disco.features.contains("muc_membersonly");
	}

	@:allow(borogove)
	private function setupNotifications() {
		if (disco == null) return;
		if (!isPrivate()) notificationSettings = { mention: true, reply: false };
	}

	@:allow(borogove)
	private function refreshDisco(?callback: ()->Void) {
		final discoGet = new DiscoInfoGet(chatId);
		discoGet.onFinished(() -> {
			if (discoGet.getResult() != null) {
				disco = discoGet.getResult();
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

	@:allow(borogove)
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
		return { iterator: () -> presence.keys() }.filter(resource -> resource != null).map((resource) -> new JID(jid.node, jid.domain, resource).asString());
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getParticipantDetails(participantId:String): Participant {
		if (participantId == getFullJid().asString()) {
			final chat = client.getDirectChat(client.accountId(), false);
			return new Participant(client.displayName(), chat.getPhoto(), chat.getPlaceholder(), true, JID.parse(chat.chatId));
		} else {
			final jid = JID.parse(participantId);
			final nick = jid.resource;
			final placeholderUri = Color.defaultPhoto(participantId, nick == null ? " " : nick.charAt(0));
			return new Participant(nick ?? "", presence[nick]?.avatarHash?.toUri(), placeholderUri, false, jid);
		}
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getMessagesBefore(beforeId:Null<String>, beforeTime:Null<String>):Promise<Array<ChatMessage>> {
		return persistence.getMessagesBefore(client.accountId(), chatId, beforeId, beforeTime).then((messages) ->
			if (messages.length > 0) {
				Promise.resolve(messages);
			} else {
				var filter:MAMQueryParams = {};
				if (beforeId != null) filter.page = { before: beforeId };
				var sync = new MessageSync(this.client, this.stream, filter, chatId);
				sync.addContext((builder, stanza) -> {
					builder = prepareIncomingMessage(builder, stanza);
					builder.syncPoint = false;
					return builder;
				});
				fetchFromSync(sync);
			}
		);
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getMessagesAfter(afterId:Null<String>, afterTime:Null<String>):Promise<Array<ChatMessage>> {
		if (afterId == lastMessageId() && !syncing()) {
			return Promise.resolve([]);
		}
		return persistence.getMessagesAfter(client.accountId(), chatId, afterId, afterTime).then((messages) ->
			if (messages.length > 0) {
				Promise.resolve(messages);
			} else {
				var filter:MAMQueryParams = {};
				if (afterId != null) filter.page = { after: afterId };
				var sync = new MessageSync(this.client, this.stream, filter, chatId);
				sync.addContext((builder, stanza) -> {
					builder = prepareIncomingMessage(builder, stanza);
					builder.syncPoint = false;
					return builder;
				});
				fetchFromSync(sync);
			}
		);
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getMessagesAround(aroundId:Null<String>, aroundTime:Null<String>):Promise<Array<ChatMessage>> {
		// TODO: fetch more from MAM if nothing locally
		return persistence.getMessagesAround(client.accountId(), chatId, aroundId, aroundTime);
	}

	@:allow(borogove)
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
		final outboxItem = outbox.newItem();
		client.storeMessages([message.build()]).then((corrected) -> {
			message.versions = corrected[0].versions[0]?.localId == localId ? cast corrected[0].versions : [message.build()];
			message.localId = toSendId;
			sendMessageStanza(message.build().asStanza(), outboxItem);
			client.notifyMessageHandlers(corrected[0], CorrectionEvent);
			if (localId == lastMessage?.localId) {
				setLastMessage(corrected[0]);
				client.trigger("chats/update", [this]);
			}
		});
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function sendMessage(message:ChatMessageBuilder):Void {
		if (uiState == Invited) uiState = Open;
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
				final outboxItem = outbox.newItem();
				client.storeMessages([message.build()]).then((stored) -> {
					sendMessageStanza(stanza, outboxItem);
					setLastMessage(stored[0]);
					client.notifyMessageHandlers(stored[0], stored[0].versions.length > 1 ? CorrectionEvent : DeliveryEvent);
					client.trigger("chats/update", [this]);
				});
			case ReactionUpdateStanza(update):
				persistence.storeReaction(client.accountId(), update).then((stored) -> {
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
		final outboxItem = outbox.newItem();
		persistence.storeReaction(client.accountId(), update).then((stored) -> {
			sendMessageStanza(update.asStanza(), outboxItem);
			if (stored != null) client.notifyMessageHandlers(stored, ReactionEvent);
		});
	}

	private function sendMessageStanza(stanza: Stanza, ?outboxItem: OutboxItem) {
		if (stanza.name != "message") throw "Can only send message stanza this way";

		if (outboxItem == null) outboxItem = outbox.newItem();
		stanza.attr.set("type", "groupchat");
		stanza.attr.set("to", chatId);
		outboxItem.handle(() -> client.sendStanza(stanza));
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function lastMessageId() {
		return lastMessage?.serverId;
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function markReadUpTo(message: ChatMessage) {
		markReadUpToMessage(message).then(_ -> {
			// Only send markers for others messages,
			// it's obvious we've read our own
			if (message.isIncoming() && message.serverId != null) {
				final stanza = new Stanza("message", { to: chatId, id: ID.long(), type: "groupchat" })
					.tag("displayed", { xmlns: "urn:xmpp:chat-markers:0", id: message.serverId }).up();
				if (message.threadId != null) {
					stanza.textTag("thread", message.threadId);
				}
				client.sendStanza(stanza);
			}

			publishMds();
			client.trigger("chats/update", [this]);
			return;
		}, e -> e != null ? Promise.reject(e) : null);
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function bookmark() {
		if (uiState == Invited) uiState = Open;
		stream.sendIq(
			new Stanza("iq", { type: "set" })
				.tag("pubsub", { xmlns: "http://jabber.org/protocol/pubsub" })
				.tag("publish", { node: "urn:xmpp:bookmarks:1" })
				.tag("item", { id: chatId })
				.tag("conference", { xmlns: "urn:xmpp:bookmarks:1", name: getDisplayName(), autojoin: uiState == Closed || uiState == Invited ? "false" : "true" })
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
		if (uiState == Invited) {
			for (invite in invites()) {
				client.sendStanza(
					new Stanza("message", { id: ID.long(), to: chatId })
						.tag("x", { xmlns: "http://jabber.org/protocol/muc#user" })
						.tag("decline", { to: invite.attr.get("from") })
						.up().up()
				);
			}
		}
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
	@:allow(borogove)
	private final caps: Caps;

	/**
		Is this search result a channel?
	**/
	public function isChannel() {
		return caps.isChannel(chatId);
	}

	@:allow(borogove)
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
	public final omemoContactDeviceIDs: Array<Int>;
	public final klass:String;
	public final notificationsFiltered: Null<Bool>;
	public final notifyMention: Bool;
	public final notifyReply: Bool;

	public function new(chatId: String, trusted: Bool, avatarSha1: Null<BytesData>, presence: Map<String, Presence>, displayName: Null<String>, uiState: Null<UiState>, isBlocked: Null<Bool>, extensions: Null<String>, readUpToId: Null<String>, readUpToBy: Null<String>, notificationsFiltered: Null<Bool>, notifyMention: Bool, notifyReply: Bool, disco: Null<Caps>, omemoContactDeviceIDs: Array<Int>, klass: String) {
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
		this.omemoContactDeviceIDs = omemoContactDeviceIDs;
		this.klass = klass;
	}

	public function toChat(client: Client, stream: GenericStream, persistence: Persistence) {
		final extensionsStanza = Stanza.parse(extensions);
		var filterN = notificationsFiltered ?? false;
		var mention = notifyMention;

		final chat = if (klass == "DirectChat") {
			new DirectChat(client, stream, persistence, chatId, uiState, isBlocked, extensionsStanza, readUpToId, readUpToBy, omemoContactDeviceIDs);
		} else if (klass == "Channel") {
			final channel = new Channel(client, stream, persistence, chatId, uiState, isBlocked, extensionsStanza, readUpToId, readUpToBy);
			channel.disco = disco ?? new Caps("", [], ["http://jabber.org/protocol/muc"], []);
			if (notificationsFiltered == null && !channel.isPrivate()) {
				mention = filterN = true;
			}
			channel;
		} else {
			throw "Unknown class of " + chatId + ": " + klass;
		}
		chat.setNotificationsInternal(filterN, mention, notifyReply);
		if (displayName != null && displayName != "") chat.displayName = displayName;
		if (avatarSha1 != null) chat.setAvatarSha1(avatarSha1);
		chat.setTrusted(trusted);
		for (resource => p in presence) {
			chat.setPresence(resource, p);
		}
		return chat;
	}
}
