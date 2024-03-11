package snikket;

import sha.SHA256;

import haxe.crypto.Base64;
import haxe.io.Bytes;
import haxe.io.BytesData;
import snikket.jingle.IceServer;
import snikket.jingle.PeerConnection;
import snikket.Caps;
import snikket.Chat;
import snikket.ChatMessage;
import snikket.Message;
import snikket.EventEmitter;
import snikket.EventHandler;
import snikket.PubsubEvent;
import snikket.Stream;
import snikket.jingle.Session;
import snikket.queries.DiscoInfoGet;
import snikket.queries.DiscoItemsGet;
import snikket.queries.ExtDiscoGet;
import snikket.queries.GenericQuery;
import snikket.queries.HttpUploadSlot;
import snikket.queries.JabberIqGatewayGet;
import snikket.queries.PubsubGet;
import snikket.queries.Push2Enable;
import snikket.queries.RosterGet;
import snikket.queries.VcardTempGet;
using Lambda;

@:expose
#if cpp
import HaxeCBridge;
@:build(HaxeCBridge.expose())
#end
class Client extends EventEmitter {
	private var stream:GenericStream;
	private var chatMessageHandlers: Array<(ChatMessage)->Void> = [];
	public var jid(default,null):JID;
	private var chats: Array<Chat> = [];
	private var persistence: Persistence;
	private final caps = new Caps(
		"https://sdk.snikket.org",
		[],
		[
			"http://jabber.org/protocol/disco#info",
			"http://jabber.org/protocol/caps",
			"urn:xmpp:avatar:metadata+notify",
			"http://jabber.org/protocol/nick+notify",
			"urn:xmpp:jingle-message:0",
			"urn:xmpp:jingle:1",
			"urn:xmpp:jingle:apps:dtls:0",
			"urn:xmpp:jingle:apps:rtp:1",
			"urn:xmpp:jingle:apps:rtp:audio",
			"urn:xmpp:jingle:apps:rtp:video",
			"urn:xmpp:jingle:transports:ice-udp:1"
		]
	);
	private var _displayName: String;
	private var fastMechanism: Null<String> = null;

	/**
		Create a new Client to connect to a particular account

		@param address the account to connect to
		@param persistence the persistence layer to use for storage
	**/
	public function new(address: String, persistence: Persistence) {
		super();
		this.jid = JID.parse(address);
		this._displayName = this.jid.node;
		this.persistence = persistence;
		stream = new Stream();
		stream.on("status/online", this.onConnected);

		stream.on("fast-token", (data) -> {
			persistence.storeLogin(this.jid.asBare().asString(), stream.clientId ?? this.jid.resource, displayName(), data.token);
			return EventHandled;
		});

		stream.on("sm/update", (data) -> {
			persistence.storeStreamManagement(accountId(), data.id, data.outbound, data.inbound, data.outbound_q);
			return EventHandled;
		});

		stream.on("sm/ack", (data) -> {
			persistence.updateMessageStatus(
				accountId(),
				data.id,
				MessageDeliveredToServer,
				notifyMessageHandlers
			);
			return EventHandled;
		});

		stream.on("sm/fail", (data) -> {
			persistence.updateMessageStatus(
				accountId(),
				data.id,
				MessageFailedToSend,
				notifyMessageHandlers
			);
			return EventHandled;
		});

		stream.on("message", function(event) {
			final stanza:Stanza = event.stanza;
			final from = stanza.attr.get("from") == null ? null : JID.parse(stanza.attr.get("from"));

			final jmiP = stanza.getChild("propose", "urn:xmpp:jingle-message:0");
			if (jmiP != null && jmiP.attr.get("id") != null) {
				final session = new IncomingProposedSession(this, from, jmiP.attr.get("id"));
				final chat = getDirectChat(from.asBare().asString());
				if (!chat.jingleSessions.exists(session.sid)) {
					chat.jingleSessions.set(session.sid, session);
					chatActivity(chat);
					session.ring();
				}
			}

			final jmiR = stanza.getChild("retract", "urn:xmpp:jingle-message:0");
			if (jmiR != null && jmiR.attr.get("id") != null) {
				final chat = getDirectChat(from.asBare().asString());
				final session = chat.jingleSessions.get(jmiR.attr.get("id"));
				if (session != null) {
					session.retract();
					chat.jingleSessions.remove(session.sid);
				}
			}

			final jmiPro = stanza.getChild("proceed", "urn:xmpp:jingle-message:0");
			if (jmiPro != null && jmiPro.attr.get("id") != null) {
				final chat = getDirectChat(from.asBare().asString());
				final session = chat.jingleSessions.get(jmiPro.attr.get("id"));
				if (session != null) {
					try {
						chat.jingleSessions.set(session.sid, session.initiate(stanza));
					} catch (e) {
						trace("JMI proceed failed", e);
					}
				}
			}

			final jmiRej = stanza.getChild("reject", "urn:xmpp:jingle-message:0");
			if (jmiRej != null && jmiRej.attr.get("id") != null) {
				final chat = getDirectChat(from.asBare().asString());
				final session = chat.jingleSessions.get(jmiRej.attr.get("id"));
				if (session != null) {
					session.retract();
					chat.jingleSessions.remove(session.sid);
				}
			}

			switch (Message.fromStanza(stanza, this.jid)) {
				case ChatMessageStanza(chatMessage):
					var chat = getChat(chatMessage.chatId());
					if (chat == null && stanza.attr.get("type") != "groupchat") chat = getDirectChat(chatMessage.chatId());
					if (chat != null) {
						final updateChat = (chatMessage) -> {
							if (chatMessage.versions.length < 1 || chat.lastMessageId() == chatMessage.serverId || chat.lastMessageId() == chatMessage.localId) {
								chat.setLastMessage(chatMessage);
								if (chatMessage.versions.length < 1) chat.setUnreadCount(chatMessage.isIncoming() ? chat.unreadCount() + 1 : 0);
								chatActivity(chat);
							}
							notifyMessageHandlers(chatMessage);
						};
						chatMessage = chat.prepareIncomingMessage(chatMessage, stanza);
						if (chatMessage.serverId == null) {
							updateChat(chatMessage);
						} else {
							persistence.storeMessage(accountId(), chatMessage, updateChat);
						}
					}
				case ReactionUpdateStanza(update):
					persistence.storeReaction(accountId(), update, (stored) -> if (stored != null) notifyMessageHandlers(stored));
				default:
					// ignore
			}

			final pubsubEvent = PubsubEvent.fromStanza(stanza);
			if (pubsubEvent != null && pubsubEvent.getFrom() != null && pubsubEvent.getNode() == "urn:xmpp:avatar:metadata" && pubsubEvent.getItems().length > 0) {
				final item = pubsubEvent.getItems()[0];
				final avatarSha1Hex = pubsubEvent.getItems()[0].attr.get("id");
				final avatarSha1 = Bytes.ofHex(avatarSha1Hex).getData();
				final metadata = item.getChild("metadata", "urn:xmpp:avatar:metadata");
				var mime = "image/png";
				if (metadata != null) {
					final info = metadata.getChild("info"); // should have xmlns matching metadata
					if (info != null && info.attr.get("type") != null) {
						mime = info.attr.get("type");
					}
				}
				final chat = this.getDirectChat(JID.parse(pubsubEvent.getFrom()).asBare().asString(), false);
				chat.setAvatarSha1(avatarSha1);
				persistence.storeChat(accountId(), chat);
				persistence.getMediaUri("sha-1", avatarSha1, (uri) -> {
					if (uri == null) {
						final pubsubGet = new PubsubGet(pubsubEvent.getFrom(), "urn:xmpp:avatar:data", avatarSha1Hex);
						pubsubGet.onFinished(() -> {
							final item = pubsubGet.getResult()[0];
							if (item == null) return;
							final dataNode = item.getChild("data", "urn:xmpp:avatar:data");
							if (dataNode == null) return;
							persistence.storeMedia(mime, Base64.decode(StringTools.replace(dataNode.getText(), "\n", "")).getData(), () -> {
								this.trigger("chats/update", [chat]);
							});
						});
						sendQuery(pubsubGet);
					} else {
						this.trigger("chats/update", [chat]);
					}
				});
			}

			if (pubsubEvent != null && pubsubEvent.getFrom() != null && JID.parse(pubsubEvent.getFrom()).asBare().asString() == accountId() && pubsubEvent.getNode() == "http://jabber.org/protocol/nick" && pubsubEvent.getItems().length > 0) {
				updateDisplayName(pubsubEvent.getItems()[0].getChildText("nick", "http://jabber.org/protocol/nick"));
			}

			return EventUnhandled; // Allow others to get this event as well
		});

		stream.onIq(Set, "jingle", "urn:xmpp:jingle:1", (stanza) -> {
			final from = stanza.attr.get("from") == null ? null : JID.parse(stanza.attr.get("from"));
			final jingle = stanza.getChild("jingle", "urn:xmpp:jingle:1");
			final chat = getDirectChat(from.asBare().asString());
			final session = chat.jingleSessions.get(jingle.attr.get("sid"));

			if (jingle.attr.get("action") == "session-initiate") {
				if (session != null) {
					try {
						chat.jingleSessions.set(session.sid, session.initiate(stanza));
					} catch (e) {
						trace("Bad session-inititate", e);
						chat.jingleSessions.remove(session.sid);
					}
				} else {
					final newSession = snikket.jingle.InitiatedSession.fromSessionInitiate(this, stanza);
					chat.jingleSessions.set(newSession.sid, newSession);
					chatActivity(chat);
					newSession.ring();
				}
			}

			if (session != null && jingle.attr.get("action") == "session-accept") {
				try {
					chat.jingleSessions.set(session.sid, session.initiate(stanza));
				} catch (e) {
					trace("session-accept failed", e);
				}
			}

			if (session != null && jingle.attr.get("action") == "session-terminate") {
				session.terminate();
				chat.jingleSessions.remove(jingle.attr.get("sid"));
			}

			if (session != null && jingle.attr.get("action") == "content-add") {
				session.contentAdd(stanza);
			}

			if (session != null && jingle.attr.get("action") == "content-accept") {
				session.contentAccept(stanza);
			}

			if (session != null && jingle.attr.get("action") == "transport-info") {
				session.transportInfo(stanza);
			}

			// jingle requires useless replies to every iq
			return IqResult;
		});

		stream.onIq(Get, "query", "http://jabber.org/protocol/disco#info", (stanza) -> {
			return IqResultElement(caps.discoReply());
		});

		stream.onIq(Set, "query", "jabber:iq:roster", (stanza) -> {
			if (
				stanza.attr.get("from") != null &&
				stanza.attr.get("from") != jid.domain
			) {
				return IqNoResult;
			}

			var roster = new RosterGet();
			roster.handleResponse(stanza);
			var items = roster.getResult();
			if (items.length == 0) return IqNoResult;

			for (item in items) {
				if (item.subscription != "remove") {
					final chat = getDirectChat(item.jid, false);
					chat.setTrusted(item.subscription == "both" || item.subscription == "from");
				}
			}
			this.trigger("chats/update", chats);

			return IqResult;
		});

		stream.on("presence", function(event) {
			final stanza:Stanza = event.stanza;
			final c = stanza.getChild("c", "http://jabber.org/protocol/caps");
			final mucUser = stanza.getChild("x", "http://jabber.org/protocol/muc#user");
			if (stanza.attr.get("from") != null && stanza.attr.get("type") == null) {
				final from = JID.parse(stanza.attr.get("from"));
				final chat = getChat(from.asBare().asString());
				if (chat == null) {
					trace("Presence for unknown JID: " + stanza.attr.get("from"));
					return EventUnhandled;
				}
				if (c == null) {
					chat.setPresence(JID.parse(stanza.attr.get("from")).resource, new Presence(null, mucUser));
					persistence.storeChat(accountId(), chat);
					if (chat.livePresence()) this.trigger("chats/update", [chat]);
				} else {
					persistence.getCaps(c.attr.get("ver"), (caps) -> {
						if (caps == null) {
							final discoGet = new DiscoInfoGet(stanza.attr.get("from"), c.attr.get("node") + "#" + c.attr.get("ver"));
							discoGet.onFinished(() -> {
								chat.setPresence(JID.parse(stanza.attr.get("from")).resource, new Presence(discoGet.getResult(), mucUser));
								if (discoGet.getResult() != null) persistence.storeCaps(discoGet.getResult());
								persistence.storeChat(accountId(), chat);
								if (chat.livePresence()) this.trigger("chats/update", [chat]);
							});
							sendQuery(discoGet);
						} else {
							chat.setPresence(JID.parse(stanza.attr.get("from")).resource, new Presence(caps, mucUser));
							persistence.storeChat(accountId(), chat);
							if (chat.livePresence()) this.trigger("chats/update", [chat]);
						}
					});
				}
				if (from.isBare()) {
					final avatarSha1Hex = stanza.findText("{vcard-temp:x:update}x/photo#");
					if (avatarSha1Hex != null) {
						final avatarSha1 = Bytes.ofHex(avatarSha1Hex).getData();
						chat.setAvatarSha1(avatarSha1);
						persistence.storeChat(accountId(), chat);
						persistence.getMediaUri("sha-1", avatarSha1, (uri) -> {
							if (uri == null) {
								final vcardGet = new VcardTempGet(from);
								vcardGet.onFinished(() -> {
									final vcard = vcardGet.getResult();
									if (vcard.photo == null) return;
									persistence.storeMedia(vcard.photo.mime, vcard.photo.data.getData(), () -> {
										this.trigger("chats/update", [chat]);
									});
								});
								sendQuery(vcardGet);
							} else {
								this.trigger("chats/update", [chat]);
							}
						});
					}
				}
				return EventHandled;
			}

			if (stanza.attr.get("from") != null && stanza.attr.get("type") == "unavailable") {
				final chat = getChat(JID.parse(stanza.attr.get("from")).asBare().asString());
				if (chat == null) {
					trace("Presence for unknown JID: " + stanza.attr.get("from"));
					return EventUnhandled;
				}
				// Maybe in the future record it as offine rather than removing it
				chat.removePresence(JID.parse(stanza.attr.get("from")).resource);
				persistence.storeChat(accountId(), chat);
				this.trigger("chats/update", [chat]);
			}

			return EventUnhandled;
		});
	}

	/**
		Get the account ID for this Client

		@return account id
	**/
	public function accountId() {
		return jid.asBare().asString();
	}

	public function displayName() {
		return _displayName;
	}

	public function setDisplayName(fn: String) {
		if (fn == null || fn == "" || fn == displayName()) return;

		stream.sendIq(
			new Stanza("iq", { type: "set" })
				.tag("pubsub", { xmlns: "http://jabber.org/protocol/pubsub" })
				.tag("publish", { node: "http://jabber.org/protocol/nick" })
				.tag("item")
				.textTag("nick", fn, { xmlns: "http://jabber.org/protocol/nick" })
				.up().up().up(),
			(response) -> { }
		);
	}

	private function updateDisplayName(fn: String) {
		if (fn == null || fn == "" || fn == displayName()) return false;
		_displayName = fn;
		persistence.storeLogin(jid.asBare().asString(), stream.clientId ?? jid.resource, fn, null);
		pingAllChannels();
		return true;
	}

	public function start() {
		persistence.getLogin(accountId(), (clientId, token, fastCount, displayName) -> {
			persistence.getStreamManagement(accountId(), (smId, smOut, smIn, smOutQ) -> {
				stream.clientId = clientId ?? ID.long();
				jid = jid.withResource(stream.clientId);
				if (!updateDisplayName(displayName) && clientId == null) {
					persistence.storeLogin(jid.asBare().asString(), stream.clientId, this.displayName(), null);
				}

				persistence.getChats(accountId(), (protoChats) -> {
					for (protoChat in protoChats) {
						chats.push(protoChat.toChat(this, stream, persistence));
					}
					persistence.getChatsUnreadDetails(accountId(), chats, (details) -> {
						for (detail in details) {
							var chat = getChat(detail.chatId);
							if (chat != null) {
								chat.setLastMessage(detail.message);
								chat.setUnreadCount(detail.unreadCount);
							}
						}
						chats.sort((a, b) -> -Reflect.compare(a.lastMessageTimestamp() ?? "0", b.lastMessageTimestamp() ?? "0"));
						this.trigger("chats/update", chats);

						stream.on("auth/password-needed", (data) -> {
							fastMechanism = data.mechanisms?.find((mech) -> mech.canFast)?.name;
							if (token == null || fastMechanism == null) {
								this.trigger("auth/password-needed", { accountId: accountId() });
							} else {
								this.stream.trigger("auth/password", { password: token, mechanism: fastMechanism, fastCount: fastCount });
							}
						});
						stream.connect(jid.asString(), smId == null || smId == "" ? null : { id: smId, outbound: smOut, inbound: smIn, outbound_q: smOutQ });
					});
				});
			});
		});
	}


	public function addPasswordNeededListener(handler:String->Void) {
		this.on("auth/password-needed", (data) -> {
			handler(data.accountId);
			return EventHandled;
		});
	}

	public function addStatusOnlineListener(handler:()->Void):Void {
		this.on("status/online", (data) -> {
			handler();
			return EventHandled;
		});
	}

	public function addChatMessageListener(handler:ChatMessage->Void):Void {
		chatMessageHandlers.push(handler);
	}

	public function addChatsUpdatedListener(handler:Array<Chat>->Void):Void {
		this.on("chats/update", (data) -> {
			handler(data);
			return EventHandled;
		});
	}

	public function addCallRingListener(handler:(Session,String)->Void):Void {
		this.on("call/ring", (data) -> {
			handler(data.session, data.chatId);
			return EventHandled;
		});
	}

	public function addCallRetractListener(handler:(String)->Void):Void {
		this.on("call/retract", (data) -> {
			handler(data.chatId);
			return EventHandled;
		});
	}

	public function addCallRingingListener(handler:(String)->Void):Void {
		this.on("call/ringing", (data) -> {
			handler(data.chatId);
			return EventHandled;
		});
	}

	public function addCallMediaListener(handler:(Session,Bool,Bool)->Void):Void {
		this.on("call/media", (data) -> {
			handler(data.session, data.audio, data.video);
			return EventHandled;
		});
	}

	public function addCallTrackListener(handler:(String,MediaStreamTrack,Array<MediaStream>)->Void):Void {
		this.on("call/track", (data) -> {
			handler(data.chatId, data.track, data.streams);
			return EventHandled;
		});
	}

	private function onConnected(data) { // Fired on connect or reconnect
		if (data != null && data.jid != null) {
			jid = JID.parse(data.jid);
			if (stream.clientId == null && !jid.isBare()) persistence.storeLogin(jid.asBare().asString(), jid.resource, displayName(), null);
		}

		if (data.resumed) return EventHandled;

		// Enable carbons
		sendStanza(
			new Stanza("iq", { type: "set", id: ID.short() })
				.tag("enable", { xmlns: "urn:xmpp:carbons:2" })
				.up()
		);

		discoverServices(new JID(null, jid.domain), (service, caps) -> {
			persistence.storeService(accountId(), service.jid.asString(), service.name, service.node, caps);
		});
		rosterGet();
		bookmarksGet(() -> {
			sync(() -> {
				persistence.getChatsUnreadDetails(accountId(), chats, (details) -> {
					for (detail in details) {
						var chat = getChat(detail.chatId) ?? getDirectChat(detail.chatId, false);
						final initialLastId = chat.lastMessageId();
						chat.setLastMessage(detail.message);
						chat.setUnreadCount(detail.unreadCount);
						if (detail.unreadCount > 0 && initialLastId != chat.lastMessageId()) {
							chatActivity(chat, false);
						}
					}
					chats.sort((a, b) -> -Reflect.compare(a.lastMessageTimestamp() ?? "0", b.lastMessageTimestamp() ?? "0"));
					this.trigger("chats/update", chats);
					// Set self to online
					sendPresence();
					pingAllChannels();
					this.trigger("status/online", {});
				});
			});
		});

		return EventHandled;
	}

	public function usePassword(password: String):Void {
		this.stream.trigger("auth/password", { password: password, requestToken: fastMechanism });
	}

	#if js
	public function prepareAttachment(source: js.html.File, callback: (Null<ChatAttachment>)->Void) { // TODO: abstract with filename, mime, and ability to convert to tink.io.Source
		persistence.findServicesWithFeature(accountId(), "urn:xmpp:http:upload:0", (services) -> {
			final sha256 = new sha.SHA256();
			tink.io.Source.ofJsFile(source.name, source).chunked().forEach((chunk) -> {
				sha256.update(chunk);
				return tink.streams.Stream.Handled.Resume;
			}).handle((o) -> switch o {
				case Depleted:
					prepareAttachmentFor(source, services, [{ algo: "sha-256", hash: sha256.digest().getData() }], callback);
				default:
					trace("Error computing attachment hash", o);
					callback(null);
			});
		});
	}

	private function prepareAttachmentFor(source: js.html.File, services: Array<{ serviceId: String }>, hashes: Array<{algo: String, hash: BytesData}>, callback: (Null<ChatAttachment>)->Void) {
		if (services.length < 1) {
			callback(null);
			return;
		}
		final httpUploadSlot = new HttpUploadSlot(services[0].serviceId, source.name, source.size, source.type, hashes);
		httpUploadSlot.onFinished(() -> {
			final slot = httpUploadSlot.getResult();
			if (slot == null) {
				prepareAttachmentFor(source, services.slice(1), hashes, callback);
			} else {
				tink.http.Client.fetch(slot.put, { method: PUT, headers: slot.putHeaders, body: tink.io.Source.RealSourceTools.idealize(tink.io.Source.ofJsFile(source.name, source), (e) -> throw e) }).all()
					.handle((o) -> switch o {
						case Success(res) if (res.header.statusCode == 201):
							callback(new ChatAttachment(source.name, source.type, source.size, [slot.get], hashes));
						default:
							prepareAttachmentFor(source, services.slice(1), hashes, callback);
					});
			}
		});
		sendQuery(httpUploadSlot);
	}
	#end

	/* Return array of chats, sorted by last activity */
	public function getChats():Array<Chat> {
		return chats.filter((chat) -> chat.uiState != Closed);
	}

	// We can ask for caps here because presumably they looked this up
	// via findAvailableChats
	public function startChat(chatId:String, displayName:Null<String>, caps:Caps):Chat {
		final existingChat = getChat(chatId);
		if (existingChat != null) {
			final channel = Std.downcast(existingChat, Channel);
			if (channel == null && caps.isChannel(chatId)) {
				chats = chats.filter((chat) -> chat.chatId == chatId);
			} else {
				if (existingChat.uiState == Closed) existingChat.uiState = Open;
				channel?.selfPing();
				this.trigger("chats/update", [existingChat]);
				return existingChat;
			}
		}

		final chat = if (caps.isChannel(chatId)) {
			final channel = new Channel(this, this.stream, this.persistence, chatId, Open, null, caps);
			chats.unshift(channel);
			channel.selfPing(false);
			channel;
		} else {
			getDirectChat(chatId, false);
		}
		if (displayName != null) chat.setDisplayName(displayName);
		persistence.storeChat(accountId(), chat);
		this.trigger("chats/update", [chat]);
		return chat;
	}

	public function getChat(chatId:String):Null<Chat> {
		return chats.find((chat) -> chat.chatId == chatId);
	}

	public function getDirectChat(chatId:String, triggerIfNew:Bool = true):DirectChat {
		for (chat in chats) {
			if (Std.isOfType(chat, DirectChat) && chat.chatId == chatId) {
				return Std.downcast(chat, DirectChat);
			}
		}
		final chat = new DirectChat(this, this.stream, this.persistence, chatId);
		persistence.storeChat(accountId(), chat);
		chats.unshift(chat);
		if (triggerIfNew) this.trigger("chats/update", [chat]);
		return chat;
	}

	@HaxeCBridge.noemit
	public function findAvailableChats(q:String, callback:(String, Array<{ chatId: String, fn: String, note: String, caps: Caps }>) -> Void) {
		var results = [];
		final query = StringTools.trim(q);
		final jid = JID.parse(query);
		final checkAndAdd = (jid) -> {
			final discoGet = new DiscoInfoGet(jid.asString());
			discoGet.onFinished(() -> {
				final resultCaps = discoGet.getResult();
				if (resultCaps == null) {
					final err = discoGet.responseStanza?.getChild("error")?.getChild(null, "urn:ietf:params:xml:ns:xmpp-stanzas");
					if (err == null || err?.name == "service-unavailable" || err?.name == "feature-not-implemented") {
						results.push({ chatId: jid.asString(), fn: query, note: jid.asString(), caps: new Caps("", [], []) });
					}
				} else {
					persistence.storeCaps(resultCaps);
					final identity = resultCaps.identities[0];
					final fn = identity?.name ?? query;
					final note = jid.asString() + (identity == null ? "" : " (" + identity.type + ")");
					results.push({ chatId: jid.asString(), fn: fn, note: note, caps: resultCaps });
				}
				callback(q, results);
			});
			sendQuery(discoGet);
		};
		if (jid.isValid()) {
			checkAndAdd(jid);
		}
		for (chat in chats) {
			if (chat.isTrusted()) {
				final resources:Map<String, Bool> = [];
				for (resource in Caps.withIdentity(chat.getCaps(), "gateway", null)) {
					resources[resource] = true;
				}
				for (resource in Caps.withFeature(chat.getCaps(), "jabber:iq:gateway")) {
					resources[resource] = true;
				}
				for (resource in resources.keys()) {
					final bareJid = JID.parse(chat.chatId);
					final fullJid = new JID(bareJid.node, bareJid.domain, resource);
					final jigGet = new JabberIqGatewayGet(fullJid.asString(), query);
					jigGet.onFinished(() -> {
						if (jigGet.getResult() == null) {
							final caps = chat.getResourceCaps(resource);
							if (bareJid.isDomain() && caps.features.contains("jid\\20escaping")) {
								checkAndAdd(new JID(query, bareJid.domain));
							} else if (bareJid.isDomain()) {
								checkAndAdd(new JID(StringTools.replace(query, "@", "%"), bareJid.domain));
							}
						} else {
							switch (jigGet.getResult()) {
								case Left(error): return;
								case Right(result):
									checkAndAdd(JID.parse(result));
							}
						}
					});
					sendQuery(jigGet);
				}
			}
		}
	}

	#if js
	public function subscribePush(reg: js.html.ServiceWorkerRegistration, push_service: String, vapid_key: { publicKey: js.html.CryptoKey, privateKey: js.html.CryptoKey}) {
		js.Browser.window.crypto.subtle.exportKey("raw", vapid_key.publicKey).then((vapid_public_raw) -> {
			reg.pushManager.subscribe(untyped {
				userVisibleOnly: true,
				applicationServerKey: vapid_public_raw
			}).then((pushSubscription) -> {
				enablePush(
					push_service,
					vapid_key.privateKey,
					pushSubscription.endpoint,
					pushSubscription.getKey(js.html.push.PushEncryptionKeyName.P256DH),
					pushSubscription.getKey(js.html.push.PushEncryptionKeyName.AUTH)
				);
			});
		});
	}

	public function enablePush(push_service: String, vapid_private_key: js.html.CryptoKey, endpoint: String, p256dh: BytesData, auth: BytesData) {
		js.Browser.window.crypto.subtle.exportKey("pkcs8", vapid_private_key).then((vapid_private_pkcs8) -> {
			sendQuery(new Push2Enable(
				jid.asBare().asString(),
				push_service,
				endpoint,
				Bytes.ofData(p256dh),
				Bytes.ofData(auth),
				"ES256",
				Bytes.ofData(vapid_private_pkcs8),
				[ "aud" => new js.html.URL(endpoint).origin ]
			));
		});
	}
	#end

	@:allow(snikket)
	private function chatActivity(chat: Chat, trigger = true) {
		if (chat.uiState == Closed) {
			chat.uiState = Open;
			persistence.storeChat(accountId(), chat);
		}
		var idx = chats.indexOf(chat);
		if (idx > 0) {
			chats.splice(idx, 1);
			chats.unshift(chat);
			if (trigger) this.trigger("chats/update", [chat]);
		}
	}

	@:allow(snikket)
	private function sendQuery(query:GenericQuery) {
		this.stream.sendIq(query.getQueryStanza(), query.handleResponse);
	}

	@:allow(snikket)
	private function sendStanza(stanza:Stanza) {
		if (stanza.attr.get("id") == null) stanza.attr.set("id", ID.long());
		stream.sendStanza(stanza);
	}

	@:allow(snikket)
	private function sendPresence(?to: String, ?augment: (Stanza)->Stanza) {
		sendStanza(
			(augment ?? (s)->s)(
				caps.addC(new Stanza("presence", to == null ? {} : { to: to }))
					.textTag("nick", displayName(), { xmlns: "http://jabber.org/protocol/nick" })
			)
		);
	}

	@:allow(snikket)
	private function getIceServers(callback: (Array<IceServer>)->Void) {
		final extDiscoGet = new ExtDiscoGet(jid.domain);
		extDiscoGet.onFinished(() -> {
			final servers = [];
			for (service in extDiscoGet.getResult()) {
				if (!["stun", "stuns", "turn", "turns"].contains(service.attr.get("type"))) continue;
				final host = service.attr.get("host");
				if (host == null || host == "") continue;
				final port = Std.parseInt(service.attr.get("port"));
				if (port == null || port < 1 || port > 65535) continue;
				final isTurn = ["turn", "turns"].contains(service.attr.get("type"));
				servers.push({
					username: service.attr.get("username"),
					credential: service.attr.get("password"),
					urls: [service.attr.get("type") + ":" + (host.indexOf(":") >= 0 ? "[" + host + "]" : host) + ":" + port + (isTurn ? "?transport=" + service.attr.get("transport") : "")]
				});
			}
			callback(servers);
		});
		sendQuery(extDiscoGet);
	}

	@:allow(snikket)
	private function discoverServices(target: JID, ?node: String, callback: ({ jid: JID, name: Null<String>, node: Null<String> }, Caps)->Void) {
		final itemsGet = new DiscoItemsGet(target.asString(), node);
		itemsGet.onFinished(()-> {
			for (item in itemsGet.getResult() ?? []) {
				final infoGet = new DiscoInfoGet(item.jid.asString(), item.node);
				infoGet.onFinished(() -> {
					callback(item, infoGet.getResult());
				});
				sendQuery(infoGet);
			}
		});
		sendQuery(itemsGet);
	}

	@:allow(snikket)
	private function notifyMessageHandlers(message: ChatMessage) {
		for (handler in chatMessageHandlers) {
			handler(message);
		}
	}

	private function rosterGet() {
		var rosterGet = new RosterGet();
		rosterGet.onFinished(() -> {
			for (item in rosterGet.getResult()) {
				var chat = getDirectChat(item.jid, false);
				chat.setTrusted(item.subscription == "both" || item.subscription == "from");
				if (item.fn != null && item.fn != "") chat.setDisplayName(item.fn);
				persistence.storeChat(accountId(), chat);
			}
			this.trigger("chats/update", chats);
		});
		sendQuery(rosterGet);
	}

	// This is called right before we're going to trigger for all chats anyway, so don't bother with single triggers
	private function bookmarksGet(callback: ()->Void) {
		final pubsubGet = new PubsubGet(null, "urn:xmpp:bookmarks:1");
		pubsubGet.onFinished(() -> {
			for (item in pubsubGet.getResult()) {
				if (item.attr.get("id") != null) {
					final chat = getChat(item.attr.get("id"));
					if (chat == null) {
						final discoGet = new DiscoInfoGet(item.attr.get("id"));
						discoGet.onFinished(() -> {
							final resultCaps = discoGet.getResult();
							if (resultCaps == null) {
								final err = discoGet.responseStanza?.getChild("error")?.getChild(null, "urn:ietf:params:xml:ns:xmpp-stanzas");
								if (err == null || err?.name == "service-unavailable" || err?.name == "feature-not-implemented") {
									final chat = getDirectChat(item.attr.get("id"), false);
									chat.updateFromBookmark(item);
									persistence.storeChat(accountId(), chat);
								}
							} else {
								persistence.storeCaps(resultCaps);
								final identity = resultCaps.identities[0];
								final conf = item.getChild("conference", "urn:xmpp:bookmarks:1");
								if (conf.attr.get("name") == null) {
									conf.attr.set("name", identity?.name);
								}
								if (resultCaps.isChannel(item.attr.get("id"))) {
									final uiState = (conf.attr.get("autojoin") == "1" || conf.attr.get("autojoin") == "true") ? Open : Closed;
									final chat = new Channel(this, this.stream, this.persistence, item.attr.get("id"), uiState, null, resultCaps);
									chat.updateFromBookmark(item);
									chats.unshift(chat);
									persistence.storeChat(accountId(), chat);
								} else {
									final chat = getDirectChat(item.attr.get("id"), false);
									chat.updateFromBookmark(item);
									persistence.storeChat(accountId(), chat);
								}
							}
						});
						sendQuery(discoGet);
					} else {
						chat.updateFromBookmark(item);
						persistence.storeChat(accountId(), chat);
					}
				}
			}
			callback();
		});
		sendQuery(pubsubGet);
	}

	private function sync(?callback: ()->Void) {
		persistence.lastId(accountId(), null, (lastId) -> doSync(callback, lastId));
	}

	private function onMAMJMI(sid: String, stanza: Stanza) {
		if (stanza.attr.get("from") == null) return;
		final from = JID.parse(stanza.attr.get("from"));
		final chat = getDirectChat(from.asBare().asString());
		if (chat.jingleSessions.exists(sid)) return; // Already know about this session
		final jmiP = stanza.getChild("propose", "urn:xmpp:jingle-message:0");
		if (jmiP == null) return;
		final session = new IncomingProposedSession(this, from, sid);
		chat.jingleSessions.set(session.sid, session);
		chatActivity(chat);
		session.ring();
	}

	private function doSync(callback: Null<()->Void>, lastId: Null<String>) {
		var thirtyDaysAgo = Date.format(
			DateTools.delta(std.Date.now(), DateTools.days(-30))
		);
		var sync = new MessageSync(
			this,
			stream,
			lastId == null ? { startTime: thirtyDaysAgo } : { page: { after: lastId } }
		);
		sync.setNewestPageFirst(false);
		sync.onMessages((messageList) -> {
			for (m in messageList.messages) {
				switch (m) {
					case ChatMessageStanza(message):
						persistence.storeMessage(accountId(), message, (m)->{});
					case ReactionUpdateStanza(update):
					persistence.storeReaction(accountId(), update, (m)->{});
					default:
						// ignore
				}
			}
			if (sync.hasMore()) {
				sync.fetchNext();
			} else {
				for (sid => stanza in sync.jmi) {
					onMAMJMI(sid, stanza);
				}
				if (callback != null) callback();
			}
		});
		sync.onError((stanza) -> {
			if (lastId != null) {
				// Gap in sync, out newest message has expired from server
				doSync(callback, null);
			} else {
				if (callback != null) callback();
			}
		});
		sync.fetchNext();
	}

	private function pingAllChannels() {
		for (chat in getChats()) {
			final channel = Std.downcast(chat, Channel);
			channel?.selfPing(channel?.disco == null);
		}
	}
}