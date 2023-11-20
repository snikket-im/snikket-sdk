package xmpp;

import haxe.io.BytesData;
import xmpp.Chat;
import xmpp.ChatMessage;
import xmpp.Color;
import xmpp.GenericStream;
import xmpp.ID;
import xmpp.MessageSync;
import xmpp.jingle.PeerConnection;
import xmpp.jingle.Session;
import xmpp.queries.DiscoInfoGet;
import xmpp.queries.MAMQuery;
using Lambda;

enum UiState {
	Pinned;
	Open; // or Unspecified
	Closed; // Archived
}

abstract class Chat {
	private var client:Client;
	private var stream:GenericStream;
	private var persistence:Persistence;
	private var avatarSha1:Null<BytesData> = null;
	private var presence:haxe.DynamicAccess<Presence> = {};
	private var trusted:Bool = false;
	public var chatId(default, null):String;
	public var jingleSessions: Map<String, xmpp.jingle.Session> = [];
	private var displayName:String;
	public var uiState = Open;
	private var extensions: Stanza;
	private var _unreadCount = 0;
	private var lastMessage: Null<ChatMessage>;

	public function new(client:Client, stream:GenericStream, persistence:Persistence, chatId:String, uiState = Open, extensions: Null<Stanza> = null) {
		this.client = client;
		this.stream = stream;
		this.persistence = persistence;
		this.chatId = chatId;
		this.uiState = uiState;
		this.extensions = extensions ?? new Stanza("extensions", { xmlns: "urn:xmpp:bookmarks:1" });
		this.displayName = chatId;
	}

	abstract public function prepareIncomingMessage(message:ChatMessage, stanza:Stanza):ChatMessage;

	abstract public function sendMessage(message:ChatMessage):Void;

	abstract public function getMessages(beforeId:Null<String>, beforeTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void;

	abstract public function getParticipants():Array<String>;

	abstract public function getParticipantDetails(participantId:String, callback:({photoUri:String, displayName:String})->Void):Void;

	abstract public function bookmark():Void;

	abstract public function close():Void;

	abstract public function markReadUpTo(message: ChatMessage):Void;

	abstract public function lastMessageId():Null<String>;

	public function lastMessageTimestamp():Null<String> {
		return lastMessage?.timestamp;
	}

	public function updateFromBookmark(item: Stanza) {
		final conf = item.getChild("conference", "urn:xmpp:bookmarks:1");
		final fn = conf.attr.get("name");
		if (fn != null) setDisplayName(fn);
		uiState = (conf.attr.get("autojoin") == "1" || conf.attr.get("autojoin") == "true") ? Open : Closed;
		extensions = conf.getChild("extensions") ?? new Stanza("extensions", { xmlns: "urn:xmpp:bookmarks:1" });
	}

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

	public function readUpTo() {
		final displayed = extensions.getChild("displayed", "urn:xmpp:chat-markers:0");
		return displayed?.attr?.get("id");
	}

	public function unreadCount() {
		return _unreadCount;
	}

	public function setUnreadCount(count:Int) {
		_unreadCount = count;
	}

	public function preview() {
		return lastMessage?.text ?? "";
	}

	public function setLastMessage(message:Null<ChatMessage>) {
		lastMessage = message;
	}

	public function setDisplayName(fn:String) {
		this.displayName = fn;
	}

	public function getDisplayName() {
		return this.displayName;
	}

	public function setPresence(resource:String, presence:Presence) {
		this.presence.set(resource, presence);
	}

	public function setCaps(resource:String, caps:Caps) {
		final presence = presence.get(resource);
		if (presence != null) {
			presence.caps = caps;
			setPresence(resource, presence);
		} else {
			setPresence(resource, new Presence(caps));
		}
	}

	public function removePresence(resource:String) {
		presence.remove(resource);
	}

	public function getCaps():KeyValueIterator<String, Caps> {
		final iter = presence.keyValueIterator();
		return {
			hasNext: iter.hasNext,
			next: () -> {
				final n = iter.next();
				return { key: n.key, value: n.value.caps };
			}
		};
	}

	public function getResourceCaps(resource:String):Caps {
		return presence[resource]?.caps ?? new Caps("", [], []);
	}

	public function setAvatarSha1(sha1: BytesData) {
		this.avatarSha1 = sha1;
	}

	public function setTrusted(trusted:Bool) {
		this.trusted = trusted;
	}

	public function isTrusted():Bool {
		return this.trusted;
	}

	public function livePresence() {
		return false;
	}

	public function canAudioCall():Bool {
		for (resource => p in presence) {
			if (p.caps?.features?.contains("urn:xmpp:jingle:apps:rtp:audio") ?? false) return true;
		}

		return false;
	}

	public function canVideoCall():Bool {
		for (resource => p in presence) {
			if (p.caps?.features?.contains("urn:xmpp:jingle:apps:rtp:video") ?? false) return true;
		}

		return false;
	}

	public function startCall(audio: Bool, video: Bool) {
		final session = new OutgoingProposedSession(client, JID.parse(chatId));
		jingleSessions.set(session.sid, session);
		session.propose(audio, video);
	}

	public function addMedia(streams: Array<MediaStream>) {
		if (callStatus() != "ongoing") throw "cannot add media when no call ongoing";
		jingleSessions.iterator().next().addMedia(streams);
	}

	public function acceptCall() {
		for (session in jingleSessions) {
			session.accept();
		}
	}

	public function hangup() {
		for (session in jingleSessions) {
			session.hangup();
			jingleSessions.remove(session.sid);
		}
	}

	public function callStatus() {
		for (session in jingleSessions) {
			return session.callStatus();
		}

		return "none";
	}

	public function dtmf() {
		for (session in jingleSessions) {
			final dtmf = session.dtmf();
			if (dtmf != null) return dtmf;
		}

		return null;
	}

	public function videoTracks() {
		return jingleSessions.flatMap((session) -> session.videoTracks());
	}

	public function onMessage(handler:ChatMessage->Void):Void {
		this.stream.on("message", function(event) {
			final stanza:Stanza = event.stanza;
			final from = JID.parse(stanza.attr.get("from"));
			if (from.asBare() != JID.parse(this.chatId)) return EventUnhandled;

			final chatMessage = ChatMessage.fromStanza(stanza, client.jid);
			if (chatMessage != null) handler(chatMessage);

			return EventUnhandled; // Allow others to get this event as well
		});
	}
}

@:expose
class DirectChat extends Chat {
	public function getParticipants() {
		return chatId.split("\n");
	}

	public function getParticipantDetails(participantId:String, callback:({photoUri:String, displayName:String})->Void) {
		final chat = client.getDirectChat(participantId);
		chat.getPhoto((photoUri) -> callback({ photoUri: photoUri, displayName: chat.getDisplayName() }));
	}

	public function getMessages(beforeId:Null<String>, beforeTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void {
		persistence.getMessages(client.accountId(), chatId, beforeId, beforeTime, (messages) -> {
			if (messages.length > 0) {
				handler(messages);
			} else {
				var filter:MAMQueryParams = { with: this.chatId };
				if (beforeId != null) filter.page = { before: beforeId };
				var sync = new MessageSync(this.client, this.stream, filter);
				sync.onMessages((messages) -> {
					for (message in messages.messages) {
						persistence.storeMessage(client.accountId(), message);
					}
					handler(messages.messages.filter((m) -> m.chatId() == chatId));
				});
				sync.fetchNext();
			}
		});
	}

	public function prepareIncomingMessage(message:ChatMessage, stanza:Stanza) {
		message.syncPoint = true; // TODO: if client is done initial MAM. right now it always is
		return message;
	}

	public function sendMessage(message:ChatMessage):Void {
		client.chatActivity(this);
		message.timestamp = message.timestamp ?? Date.format(std.Date.now());
		message.direction = MessageSent;
		message.from = client.jid;
		message.sender = message.from.asBare();
		message.replyTo = [message.sender];
		message.recipients = getParticipants().map((p) -> JID.parse(p));
		persistence.storeMessage(client.accountId(), message);
		for (recipient in message.recipients) {
			message.to = recipient;
			client.sendStanza(message.asStanza());
		}
		setLastMessage(message);
		client.trigger("chats/update", [this]);
	}

	public function lastMessageId() {
		return lastMessage?.localId ?? lastMessage?.serverId;
	}

	public function markReadUpTo(message: ChatMessage) {
		if (readUpTo() == message.localId || readUpTo() == message.serverId) return;
		final upTo = message.localId ?? message.serverId;
		_unreadCount = 0; // TODO
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

		var displayed = extensions.getChild("displayed", "urn:xmpp:chat-markers:0");
		if (displayed == null) {
			displayed = new Stanza("displayed", { xmlns: "urn:xmpp:chat-markers:0", id: upTo });
			extensions.addChild(displayed);
		} else {
			displayed.attr.set("id", upTo);
		}
		persistence.storeChat(client.accountId(), this);
		client.trigger("chats/update", [this]);
	}

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

	public function close() {
		// Should this remove from roster?
		uiState = Closed;
		persistence.storeChat(client.accountId(), this);
		client.trigger("chats/update", [this]);
	}
}

@:expose
class Channel extends Chat {
	public var disco: Caps = new Caps("", [], ["http://jabber.org/protocol/muc"]);
	private var inSync = true;

	public function new(client:Client, stream:GenericStream, persistence:Persistence, chatId:String, uiState = Open, extensions = null, ?disco: Caps) {
		super(client, stream, persistence, chatId, uiState, extensions);
		if (disco != null) this.disco = disco;
		selfPing(disco == null);
	}

	public function selfPing(shouldRefreshDisco = true) {
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
					if (err.name == "service-unavailable" || err.name == "feature-not-implemented") return; // Error, success!
					if (err.name == "remote-server-not-found" || err.name == "remote-server-timeout") return; // Timeout, retry later
					if (err.name == "item-not-found") return; // Nick was changed?
					(shouldRefreshDisco ? refreshDisco : (cb)->cb())(() -> {
						presence = {}; // About to ask for a fresh set
						inSync = false;
						client.sendPresence(
							getFullJid().asString(),
							(stanza) -> {
								stanza.tag("x", { xmlns: "http://jabber.org/protocol/muc" });
								if (disco.features.contains("urn:xmpp:mam:2")) stanza.tag("history", { maxchars: "0" }).up();
								// TODO: else since (last message we know about)
								stanza.up();
								return stanza;
							}
						);
					});
				}
			}
		);
	}

	override public function setPresence(resource:String, presence:Presence) {
		super.setPresence(resource, presence);
		if (!inSync && resource == client.displayName()) {
			persistence.lastId(client.accountId(), chatId, doSync);
		}
	}

	private function doSync(lastId: Null<String>) {
		var thirtyDaysAgo = Date.format(
			DateTools.delta(std.Date.now(), DateTools.days(-3))
		);
		var sync = new MessageSync(
			client,
			stream,
			lastId == null ? { startTime: thirtyDaysAgo } : { page: { after: lastId } },
			chatId
		);
		sync.setNewestPageFirst(false);
		sync.onMessages((messageList) -> {
			for (message in messageList.messages) {
				persistence.storeMessage(client.accountId(), message);
			}
			if (sync.hasMore()) {
				sync.fetchNext();
			} else {
				inSync = true;
				final lastFromSync = messageList.messages[messageList.messages.length - 1];
				if (lastFromSync != null && Reflect.compare(lastFromSync.timestamp, lastMessageTimestamp()) > 0) {
					setLastMessage(lastFromSync);
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

	public function refreshDisco(?callback: ()->Void) {
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

	override public function livePresence() {
		return presence.exists(client.displayName());
	}

	private function getFullJid() {
		return JID.parse(chatId).withResource(client.displayName());
	}

	public function getParticipants() {
		final jid = JID.parse(chatId);
		return presence.keys().map((resource) -> new JID(jid.node, jid.domain, resource).asString());
	}

	public function getParticipantDetails(participantId:String, callback:({photoUri:String, displayName:String})->Void) {
		if (participantId == getFullJid().asString()) {
			client.getDirectChat(client.accountId(), false).getPhoto((photoUri) -> {
				callback({ photoUri: photoUri, displayName: client.displayName() });
			});
		} else {
			final nick = JID.parse(participantId).resource;
			final photoUri = Color.defaultPhoto(participantId, nick.charAt(0));
			callback({ photoUri: photoUri, displayName: nick });
		}
	}

	public function getMessages(beforeId:Null<String>, beforeTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void {
		persistence.getMessages(client.accountId(), chatId, beforeId, beforeTime, (messages) -> {
			if (messages.length > 0) {
				handler(messages);
			} else {
				var filter:MAMQueryParams = {};
				if (beforeId != null) filter.page = { before: beforeId };
				var sync = new MessageSync(this.client, this.stream, filter, chatId);
				sync.onMessages((messages) -> {
					for (message in messages.messages) {
						message = prepareIncomingMessage(message, new Stanza("message", { from: message.senderId() }));
						persistence.storeMessage(client.accountId(), message);
					}
					handler(messages.messages.filter((m) -> m.chatId() == chatId));
				});
				sync.fetchNext();
			}
		});
	}

	public function prepareIncomingMessage(message:ChatMessage, stanza:Stanza) {
		// TODO: mark type!=groupchat as whisper somehow
		message.syncPoint = inSync;
		message.sender = JID.parse(stanza.attr.get("from")); // MUC always needs full JIDs
		if (message.senderId() == getFullJid().asString()) {
			message.recipients = message.replyTo;
			message.direction = MessageSent;
		}
		return message;
	}

	public function sendMessage(message:ChatMessage):Void {
		client.chatActivity(this);
		message.timestamp = message.timestamp ?? Date.format(std.Date.now());
		message.direction = MessageSent;
		message.from = client.jid;
		message.sender = getFullJid();
		message.replyTo = [message.sender];
		message.to = JID.parse(chatId);
		message.recipients = [message.to];
		persistence.storeMessage(client.accountId(), message);
		client.sendStanza(message.asStanza("groupchat"));
		setLastMessage(message);
		client.trigger("chats/update", [this]);
	}

	public function lastMessageId() {
		return lastMessage?.serverId;
	}

	public function markReadUpTo(message: ChatMessage) {
		if (readUpTo() == message.serverId) return;
		final upTo = message.serverId;
		_unreadCount = 0; // TODO
		if (upTo == null) return; // Can't mark as read with no id
		final stanza = new Stanza("message", { to: chatId, id: ID.long() })
			.tag("displayed", { xmlns: "urn:xmpp:chat-markers:0", id: upTo }).up();
		if (message.threadId != null) {
			stanza.textTag("thread", message.threadId);
		}
		client.sendStanza(stanza);

		var displayed = extensions.getChild("displayed", "urn:xmpp:chat-markers:0");
		if (displayed == null) {
			displayed = new Stanza("displayed", { xmlns: "urn:xmpp:chat-markers:0", id: upTo });
			extensions.addChild(displayed);
		} else {
			displayed.attr.set("id", upTo);
		}
		persistence.storeChat(client.accountId(), this);
		bookmark(); // TODO: what if not previously bookmarked?
		client.trigger("chats/update", [this]);
	}

	public function bookmark() {
		stream.sendIq(
			new Stanza("iq", { type: "set" })
				.tag("pubsub", { xmlns: "http://jabber.org/protocol/pubsub" })
				.tag("publish", { node: "urn:xmpp:bookmarks:1" })
				.tag("item", { id: chatId })
				.tag("conference", { xmlns: "urn:xmpp:bookmarks:1", name: getDisplayName(), autojoin: uiState == Closed ? "false" : "true" })
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

	public function close() {
		uiState = Closed;
		persistence.storeChat(client.accountId(), this);
		selfPing(false);
		bookmark(); // TODO: what if not previously bookmarked?
		client.trigger("chats/update", [this]);
	}
}

@:expose
class SerializedChat {
	public final chatId:String;
	public final trusted:Bool;
	public final avatarSha1:Null<BytesData>;
	public final presence:haxe.DynamicAccess<Presence>;
	public final displayName:Null<String>;
	public final uiState:String;
	public final extensions:String;
	public final disco:Null<Caps>;
	public final klass:String;

	public function new(chatId: String, trusted: Bool, avatarSha1: Null<BytesData>, presence: haxe.DynamicAccess<Presence>, displayName: Null<String>, uiState: Null<String>, extensions: Null<String>, disco: Null<Caps>, klass: String) {
		this.chatId = chatId;
		this.trusted = trusted;
		this.avatarSha1 = avatarSha1;
		this.presence = presence;
		this.displayName = displayName;
		this.uiState = uiState ?? "Open";
		this.extensions = extensions ?? "<extensions xmlns='urn:app:bookmarks:1' />";
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
			new DirectChat(client, stream, persistence, chatId, uiStateEnum, extensionsStanza);
		} else if (klass == "Channel") {
			final channel = new Channel(client, stream, persistence, chatId, uiStateEnum, extensionsStanza);
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
