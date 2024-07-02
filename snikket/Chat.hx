package snikket;

import haxe.io.BytesData;
import snikket.Chat;
import snikket.ChatMessage;
import snikket.Color;
import snikket.GenericStream;
import snikket.ID;
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
	@:allow(snikket)
	private var extensions: Stanza;
	private var _unreadCount = 0;
	private var lastMessage: Null<ChatMessage>;
	private var readUpToId: Null<String>;
	@:allow(snikket)
	private var readUpToBy: Null<String>;

	@:allow(snikket)
	private function new(client:Client, stream:GenericStream, persistence:Persistence, chatId:String, uiState = Open, extensions: Null<Stanza> = null, readUpToId: Null<String> = null, readUpToBy: Null<String> = null) {
		this.client = client;
		this.stream = stream;
		this.persistence = persistence;
		this.chatId = chatId;
		this.uiState = uiState;
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
	abstract public function getMessages(beforeId:Null<String>, beforeTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void;

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
		@param callback takes two arguments, the display name and the photo URI
	**/
	abstract public function getParticipantDetails(participantId:String, callback:(String, String)->Void):Void;

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

	/**
		Archive this chat
	**/
	abstract public function close():Void;

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
		uiState = (conf.attr.get("autojoin") == "1" || conf.attr.get("autojoin") == "true") ? Open : Closed;
		extensions = conf.getChild("extensions") ?? new Stanza("extensions", { xmlns: "urn:xmpp:bookmarks:1" });
	}

	/**
		Get an image to represent this Chat

		@param callback takes one argument, the URI to the image
	**/
	public function getPhoto(callback:(String)->Void) {
		if (avatarSha1 != null) {
			persistence.getMediaUri("sha-1", avatarSha1, (uri) -> {
				if (uri != null) {
					callback(uri);
				} else {
					callback(Color.defaultPhoto(chatId, getDisplayName().charAt(0)));
				}
			});
		} else {
			callback(Color.defaultPhoto(chatId, getDisplayName().charAt(0)));
		}
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
		return lastMessage?.text ?? "";
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
		return false;
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
		persistence.getMessages(client.accountId(), chatId, null, null, (messages) -> {
			var i = messages.length;
			while (--i >= 0) {
				if (messages[i].serverId == readUpToId) break;
			}
			if (i > 0) _unreadCount = messages.length - (i + 1);
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
	private function new(client:Client, stream:GenericStream, persistence:Persistence, chatId:String, uiState = Open, extensions: Null<Stanza> = null, readUpToId: Null<String> = null, readUpToBy: Null<String> = null) {
		super(client, stream, persistence, chatId, uiState, extensions, readUpToId, readUpToBy);
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getParticipants(): Array<String> {
		return chatId.split("\n");
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getParticipantDetails(participantId:String, callback:(String, String)->Void) {
		final chat = client.getDirectChat(participantId);
		chat.getPhoto((photoUri) -> callback(chat.getDisplayName(), photoUri));
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getMessages(beforeId:Null<String>, beforeTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void {
		persistence.getMessages(client.accountId(), chatId, beforeId, beforeTime, (messages) -> {
			if (messages.length > 0) {
				handler(messages);
			} else {
				var filter:MAMQueryParams = { with: this.chatId };
				if (beforeId != null) filter.page = { before: beforeId };
				var sync = new MessageSync(this.client, this.stream, filter);
				sync.onMessages((messageList) -> {
					final chatMessages = [];
					for (m in messageList.messages) {
						switch (m) {
							case ChatMessageStanza(message):
								persistence.storeMessage(client.accountId(), message, (m)->{});
								if (message.chatId() == chatId) chatMessages.push(message);
							case ReactionUpdateStanza(update):
								persistence.storeReaction(client.accountId(), update, (m)->{});
							default:
								// ignore
						}
					}
					handler(chatMessages);
				});
				sync.fetchNext();
			}
		});
	}

	@:allow(snikket)
	private function prepareIncomingMessage(message:ChatMessage, stanza:Stanza) {
		message.syncPoint = true; // TODO: if client is done initial MAM. right now it always is
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
		persistence.storeMessage(client.accountId(), message, (corrected) -> {
			toSend.versions = corrected.versions;
			for (recipient in message.recipients) {
				message.to = recipient;
				client.sendStanza(toSend.asStanza());
			}
			if (localId == lastMessage?.localId) {
				setLastMessage(corrected);
				client.trigger("chats/update", [this]);
			}
			client.notifyMessageHandlers(corrected);
		});
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function sendMessage(message:ChatMessage):Void {
		client.chatActivity(this);
		message = prepareOutgoingMessage(message);
		final fromStanza = Message.fromStanza(message.asStanza(), client.jid);
		switch (fromStanza) {
			case ChatMessageStanza(_):
				persistence.storeMessage(client.accountId(), message, (stored) -> {
					for (recipient in message.recipients) {
						message.to = recipient;
						client.sendStanza(message.asStanza());
					}
					setLastMessage(message);
					client.trigger("chats/update", [this]);
					client.notifyMessageHandlers(stored);
				});
			case ReactionUpdateStanza(update):
				persistence.storeReaction(client.accountId(), update, (stored) -> {
					for (recipient in message.recipients) {
						message.to = recipient;
						client.sendStanza(message.asStanza());
					}
					if (stored != null) client.notifyMessageHandlers(stored);
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
		final update = new ReactionUpdate(ID.long(), null, m.localId, m.chatId(), Date.format(std.Date.now()), client.accountId(), reactions);
		persistence.storeReaction(client.accountId(), update, (stored) -> {
			final stanza = update.asStanza();
			for (recipient in getParticipants()) {
				stanza.attr.set("to", recipient);
				client.sendStanza(stanza);
			}
			if (stored != null) client.notifyMessageHandlers(stored);
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
		for (recipient in getParticipants()) {
			// TODO: extended addressing when relevant
			final stanza = new Stanza("message", { to: recipient, id: ID.long() })
				.tag("displayed", { xmlns: "urn:xmpp:chat-markers:0", id: upTo }).up();
			if (message.threadId != null) {
				stanza.textTag("thread", message.threadId);
			}
			client.sendStanza(stanza);
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

	@HaxeCBridge.noemit // on superclass as abstract
	public function close() {
		// Should this remove from roster?
		uiState = Closed;
		persistence.storeChat(client.accountId(), this);
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
	private function new(client:Client, stream:GenericStream, persistence:Persistence, chatId:String, uiState = Open, extensions = null, readUpToId = null, readUpToBy = null, ?disco: Caps) {
		super(client, stream, persistence, chatId, uiState, extensions, readUpToId, readUpToBy);
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
		super.setPresence(resource, presence);
		if (!inSync && presence?.mucUser?.allTags("status").find((status) -> status.attr.get("code") == "110") != null) {
			persistence.lastId(client.accountId(), chatId, doSync);
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
			for (m in messageList.messages) {
				switch (m) {
					case ChatMessageStanza(message):
						persistence.storeMessage(client.accountId(), message, (m)->{});
						if (message.chatId() == chatId) chatMessages.push(message);
					case ReactionUpdateStanza(update):
						persistence.storeReaction(client.accountId(), update, (m)->{});
					default:
						// ignore
				}
			}
			if (sync.hasMore()) {
				sync.fetchNext();
			} else {
				inSync = true;
				final lastFromSync = chatMessages[chatMessages.length - 1];
				if (lastFromSync != null && (lastMessageTimestamp() == null || Reflect.compare(lastFromSync.timestamp, lastMessageTimestamp()) > 0)) {
					setLastMessage(lastFromSync);
					client.sortChats();
					client.trigger("chats/update", [this]);
				}
			}
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
		return lastMessage.sender.resource + ": " + super.preview();
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
	public function getParticipantDetails(participantId:String, callback:(String, String)->Void) {
		if (participantId == getFullJid().asString()) {
			client.getDirectChat(client.accountId(), false).getPhoto((photoUri) -> {
				callback(client.displayName(), photoUri);
			});
		} else {
			final nick = JID.parse(participantId).resource;
			final photoUri = Color.defaultPhoto(participantId, nick == null ? " " : nick.charAt(0));
			callback(nick, photoUri);
		}
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function getMessages(beforeId:Null<String>, beforeTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void {
		persistence.getMessages(client.accountId(), chatId, beforeId, beforeTime, (messages) -> {
			if (messages.length > 0) {
				handler(messages);
			} else {
				var filter:MAMQueryParams = {};
				if (beforeId != null) filter.page = { before: beforeId };
				var sync = new MessageSync(this.client, this.stream, filter, chatId);
				sync.onMessages((messageList) -> {
					final chatMessages = [];
					for (m in messageList.messages) {
						switch (m) {
							case ChatMessageStanza(message):
								final chatMessage = prepareIncomingMessage(message, new Stanza("message", { from: message.senderId() }));
								persistence.storeMessage(client.accountId(), chatMessage, (m)->{});
								if (message.chatId() == chatId) chatMessages.push(message);
							case ReactionUpdateStanza(update):
								persistence.storeReaction(client.accountId(), update, (m)->{});
							default:
								// ignore
						}
					}
					handler(chatMessages);
				});
				sync.fetchNext();
			}
		});
	}

	@:allow(snikket)
	private function prepareIncomingMessage(message:ChatMessage, stanza:Stanza) {
		message.syncPoint = inSync;
		message.sender = JID.parse(stanza.attr.get("from")); // MUC always needs full JIDs
		if (message.senderId() == getFullJid().asString()) {
			message.recipients = message.replyTo;
			message.direction = MessageSent;
		}
		return message;
	}

	private function prepareOutgoingMessage(message:ChatMessage) {
		message.isGroupchat = true;
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
		persistence.storeMessage(client.accountId(), message, (corrected) -> {
			toSend.versions = corrected.versions;
			client.sendStanza(toSend.asStanza());
			if (localId == lastMessage?.localId) {
				setLastMessage(corrected);
				client.trigger("chats/update", [this]);
			}
			client.notifyMessageHandlers(corrected);
		});
	}

	@HaxeCBridge.noemit // on superclass as abstract
	public function sendMessage(message:ChatMessage):Void {
		client.chatActivity(this);
		message = prepareOutgoingMessage(message);
		final stanza = message.asStanza();
		// Fake from as it will look on reflection for storage purposes
		stanza.attr.set("from", getFullJid().asString());
		final fromStanza = Message.fromStanza(stanza, client.jid);
		stanza.attr.set("from", client.jid.asString());
		switch (fromStanza) {
			case ChatMessageStanza(_):
				persistence.storeMessage(client.accountId(), message, (stored) -> {
					client.sendStanza(stanza);
					setLastMessage(stored);
					client.trigger("chats/update", [this]);
					client.notifyMessageHandlers(stored);
				});
			case ReactionUpdateStanza(update):
				persistence.storeReaction(client.accountId(), update, (stored) -> {
					client.sendStanza(stanza);
					if (stored != null) client.notifyMessageHandlers(stored);
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
		final update = new ReactionUpdate(ID.long(), m.serverId, null, m.chatId(), Date.format(std.Date.now()), client.accountId(), reactions);
		persistence.storeReaction(client.accountId(), update, (stored) -> {
			final stanza = update.asStanza();
			stanza.attr.set("to", chatId);
			client.sendStanza(stanza);
			if (stored != null) client.notifyMessageHandlers(stored);
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

	@HaxeCBridge.noemit // on superclass as abstract
	public function close() {
		uiState = Closed;
		persistence.storeChat(client.accountId(), this);
		selfPing(false);
		bookmark(); // TODO: what if not previously bookmarked?
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
	public final uiState:String;
	public final extensions:String;
	public final readUpToId:Null<String>;
	public final readUpToBy:Null<String>;
	public final disco:Null<Caps>;
	public final klass:String;

	public function new(chatId: String, trusted: Bool, avatarSha1: Null<BytesData>, presence: Map<String, Presence>, displayName: Null<String>, uiState: Null<String>, extensions: Null<String>, readUpToId: Null<String>, readUpToBy: Null<String>, disco: Null<Caps>, klass: String) {
		this.chatId = chatId;
		this.trusted = trusted;
		this.avatarSha1 = avatarSha1;
		this.presence = presence;
		this.displayName = displayName;
		this.uiState = uiState ?? "Open";
		this.extensions = extensions ?? "<extensions xmlns='urn:app:bookmarks:1' />";
		this.readUpToId = readUpToId;
		this.readUpToBy = readUpToBy;
		this.disco = disco;
		this.klass = klass;
	}

	public function toChat(client: Client, stream: GenericStream, persistence: Persistence) {
		final uiStateEnum = switch (uiState) {
			case "Pinned": Pinned;
			case "Closed": Closed;
			default: Open;
		}

		final extensionsStanza = Stanza.fromXml(Xml.parse(extensions));

		final chat = if (klass == "DirectChat") {
			new DirectChat(client, stream, persistence, chatId, uiStateEnum, extensionsStanza, readUpToId, readUpToBy);
		} else if (klass == "Channel") {
			final channel = new Channel(client, stream, persistence, chatId, uiStateEnum, extensionsStanza, readUpToId, readUpToBy);
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
