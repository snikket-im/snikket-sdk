package xmpp;

import haxe.crypto.Base64;
import haxe.io.Bytes;
import haxe.io.BytesData;
import js.html.rtc.IceServer; // only typedefs, should be portable
import xmpp.Caps;
import xmpp.Chat;
import xmpp.ChatMessage;
import xmpp.EventEmitter;
import xmpp.EventHandler;
import xmpp.PubsubEvent;
import xmpp.Stream;
import xmpp.jingle.Session;
import xmpp.queries.DiscoInfoGet;
import xmpp.queries.ExtDiscoGet;
import xmpp.queries.GenericQuery;
import xmpp.queries.JabberIqGatewayGet;
import xmpp.queries.PubsubGet;
import xmpp.queries.Push2Enable;
import xmpp.queries.RosterGet;
import xmpp.queries.VcardTempGet;
using Lambda;

@:expose
class Client extends xmpp.EventEmitter {
	private var stream:GenericStream;
	private var chatMessageHandlers: Array<(ChatMessage)->Void> = [];
	public var jid(default,null):String;
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

	public function new(jid: String, persistence: Persistence) {
		super();
		this.jid = jid;
		this._displayName = JID.parse(jid).node;
		this.persistence = persistence;
		stream = new Stream();
		stream.on("status/online", this.onConnected);
		stream.on("sm/update", (data) -> {
			persistence.storeStreamManagement(accountId(), data.id, data.outbound, data.inbound, data.outbound_q);
			return EventHandled;
		});

		stream.on("sm/ack", (data) -> {
			persistence.updateMessageStatus(
				accountId(),
				data.id,
				MessageDeliveredToServer,
				(chatMessage) -> {
					for (handler in chatMessageHandlers) {
						handler(chatMessage);
					}
				}
			);
			return EventHandled;
		});

		stream.on("sm/fail", (data) -> {
			persistence.updateMessageStatus(
				accountId(),
				data.id,
				MessageFailedToSend,
				(chatMessage) -> {
					for (handler in chatMessageHandlers) {
						handler(chatMessage);
					}
				}
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

			var chatMessage = ChatMessage.fromStanza(stanza, jid);
			if (chatMessage != null) {
				var chat = getChat(chatMessage.chatId());
				if (chat == null && stanza.attr.get("type") != "groupchat") chat = getDirectChat(chatMessage.chatId());
				if (chat != null) {
					final updateChat = (chatMessage) -> {
						if (chatMessage.versions.length < 1 || chat.lastMessageId() == chatMessage.serverId || chat.lastMessageId() == chatMessage.localId) {
							chat.setLastMessage(chatMessage);
							if (chatMessage.versions.length < 1) chat.setUnreadCount(chatMessage.isIncoming() ? chat.unreadCount() + 1 : 0);
							chatActivity(chat);
						}
						for (handler in chatMessageHandlers) {
							handler(chatMessage);
						}
					};
					chatMessage = chat.prepareIncomingMessage(chatMessage, stanza);
					final replace = stanza.getChild("replace", "urn:xmpp:message-correct:0");
					if (replace == null || replace.attr.get("id") == null) {
						if (chatMessage.serverId != null) persistence.storeMessage(accountId(), chatMessage);
						updateChat(chatMessage);
					} else {
						persistence.correctMessage(accountId(), replace.attr.get("id"), chatMessage, updateChat);
					}
				}
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
				persistence.storeChat(jid, chat);
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
				setDisplayName(pubsubEvent.getItems()[0].getChildText("nick", "http://jabber.org/protocol/nick"));
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
						chat.jingleSessions.remove(session.sid);
					}
				} else {
					final newSession = xmpp.jingle.InitiatedSession.fromSessionInitiate(this, stanza);
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
				stanza.attr.get("from") != JID.parse(jid).domain
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
			if (stanza.attr.get("from") != null && stanza.attr.get("type") == null) {
				final from = JID.parse(stanza.attr.get("from"));
				final chat = getChat(from.asBare().asString());
				if (chat == null) {
					trace("Presence for unknown JID: " + stanza.attr.get("from"));
					return EventUnhandled;
				}
				if (c == null) {
					chat.setCaps(JID.parse(stanza.attr.get("from")).resource, null);
					persistence.storeChat(jid, chat);
					if (chat.livePresence()) this.trigger("chats/update", [chat]);
				} else {
					persistence.getCaps(c.attr.get("ver"), (caps) -> {
						if (caps == null) {
							final discoGet = new DiscoInfoGet(stanza.attr.get("from"), c.attr.get("node") + "#" + c.attr.get("ver"));
							discoGet.onFinished(() -> {
								chat.setCaps(JID.parse(stanza.attr.get("from")).resource, discoGet.getResult());
								if (discoGet.getResult() != null) persistence.storeCaps(discoGet.getResult());
								persistence.storeChat(jid, chat);
								if (chat.livePresence()) this.trigger("chats/update", [chat]);
							});
							sendQuery(discoGet);
						} else {
							chat.setCaps(JID.parse(stanza.attr.get("from")).resource, caps);
							persistence.storeChat(jid, chat);
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
				persistence.storeChat(jid, chat);
				this.trigger("chats/update", [chat]);
			}

			return EventUnhandled;
		});
	}

	public function accountId() {
		return JID.parse(jid).asBare().asString();
	}

	public function displayName() {
		return _displayName;
	}

	public function setDisplayName(fn: String) {
		// TODO: persist
		// TODO: do self ping on all channels to maybe change nick
		_displayName = fn;
	}

	public function start() {
		persistence.getChats(jid, (protoChats) -> {
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

				persistence.getStreamManagement(accountId(), (smId, smOut, smIn, smOutQ) -> {
					persistence.getLogin(jid, (login) -> {
						var ajid = jid;
						if (login.clientId != null) ajid = JID.parse(jid).asBare().asString() + "/" + login.clientId;
						if (login.token == null) {
							stream.on("auth/password-needed", (data)->this.trigger("auth/password-needed", { jid: this.jid }));
						} else {
							stream.on("auth/password-needed", (data)->this.stream.trigger("auth/password", { password: login.token }));
						}
						stream.connect(ajid, smId == null || smId == "" ? null : { id: smId, outbound: smOut, inbound: smIn, outbound_q: smOutQ });
					});
				});
			});
		});
	}

	public function addChatMessageListener(handler:ChatMessage->Void):Void {
		chatMessageHandlers.push(handler);
	}

	private function onConnected(data) { // Fired on connect or reconnect
		if (data != null && data.jid != null) {
			final jidp = JID.parse(data.jid);
			if (!jidp.isBare()) persistence.storeLogin(jidp.asBare().asString(), jidp.resource, null);
		}

		if (data.resumed) return EventHandled;

		// Enable carbons
		sendStanza(
			new Stanza("iq", { type: "set", id: ID.short() })
				.tag("enable", { xmlns: "urn:xmpp:carbons:2" })
				.up()
		);

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
					this.trigger("status/online", {});
				});
			});
		});

		return EventHandled;
	}

	public function usePassword(password: String):Void {
		this.stream.trigger("auth/password", { password: password });
	}

	/* Return array of chats, sorted by last activity */
	public function getChats():Array<Chat> {
		return chats.filter((chat) -> chat.uiState != Closed);
	}

	// We can ask for caps here because presumably they looked this up
	// via findAvailableChats
	public function startChat(chatId:String, fn:Null<String>, caps:Caps):Chat {
		final existingChat = getChat(chatId);
		if (existingChat != null) {
			if (existingChat.uiState == Closed) existingChat.uiState = Open;
			Std.downcast(existingChat, Channel)?.selfPing();
			this.trigger("chats/update", [existingChat]);
			return existingChat;
		}

		final chat = if (caps.isChannel(chatId)) {
			final channel = new Channel(this, this.stream, this.persistence, chatId, Open, null, caps);
			chats.unshift(channel);
			channel;
		} else {
			getDirectChat(chatId, false);
		}
		if (fn != null) chat.setDisplayName(fn);
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
		persistence.storeChat(jid, chat);
		chats.unshift(chat);
		if (triggerIfNew) this.trigger("chats/update", [chat]);
		return chat;
	}

	public function findAvailableChats(q:String, callback:(q:String, results:Array<{ chatId: String, fn: String, note: String, caps: Caps }>) -> Void) {
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

	public function chatActivity(chat: Chat, trigger = true) {
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

	/* Internal-ish methods */
	public function sendQuery(query:GenericQuery) {
		this.stream.sendIq(query.getQueryStanza(), query.handleResponse);
	}

	public function sendStanza(stanza:Stanza) {
		stream.sendStanza(stanza);
	}

	public function sendPresence(?to: String, ?augment: (Stanza)->Stanza) {
		sendStanza(
			(augment ?? (s)->s)(
				caps.addC(new Stanza("presence", to == null ? {} : { to: to }))
					.textTag("nick", displayName(), { xmlns: "http://jabber.org/protocol/nick" })
			)
		);
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
				jid,
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

	public function getIceServers(callback: (Array<IceServer>)->Void) {
		final extDiscoGet = new ExtDiscoGet(JID.parse(this.jid).domain);
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

	private function rosterGet() {
		var rosterGet = new RosterGet();
		rosterGet.onFinished(() -> {
			for (item in rosterGet.getResult()) {
				var chat = getDirectChat(item.jid, false);
				chat.setTrusted(item.subscription == "both" || item.subscription == "from");
				if (item.fn != null && item.fn != "") chat.setDisplayName(item.fn);
				persistence.storeChat(jid, chat);
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
			for (message in messageList.messages) {
				persistence.storeMessage(jid, message);
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
}
