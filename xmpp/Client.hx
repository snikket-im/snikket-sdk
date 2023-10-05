package xmpp;

import haxe.crypto.Base64;
import haxe.io.Bytes;
import haxe.io.BytesData;
import js.html.rtc.IceServer; // only typedefs, should be portable
import xmpp.Caps;
import xmpp.Chat;
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

typedef ChatList = Array<Chat>;

@:expose
class Client extends xmpp.EventEmitter {
	private var stream:GenericStream;
	private var chatMessageHandlers: Array<(ChatMessage)->Void> = [];
	public var jid(default,null):String;
	private var chats: ChatList = [];
	private var persistence: Persistence;
	private final caps = new Caps(
		"https://sdk.snikket.org",
		[],
		[
			"http://jabber.org/protocol/disco#info",
			"http://jabber.org/protocol/caps",
			"urn:xmpp:avatar:metadata+notify",
			"urn:xmpp:jingle-message:0",
			"urn:xmpp:jingle:1",
			"urn:xmpp:jingle:apps:dtls:0",
			"urn:xmpp:jingle:apps:rtp:1",
			"urn:xmpp:jingle:apps:rtp:audio",
			"urn:xmpp:jingle:apps:rtp:video",
			"urn:xmpp:jingle:transports:ice-udp:1"
		]
	);

	public function new(jid: String, persistence: Persistence) {
		super();
		this.jid = jid;
		this.persistence = persistence;
		stream = new Stream();
		stream.on("status/online", this.onConnected);
	}

	public function start() {
		persistence.getLogin(jid, (login) -> {
			if (login.token == null) {
				stream.on("auth/password-needed", (data)->this.trigger("auth/password-needed", { jid: this.jid }));
			} else {
				stream.on("auth/password-needed", (data)->this.stream.trigger("auth/password", { password: login.token }));
			}
			stream.connect(login.clientId == null ? jid : jid + "/" + login.clientId);
		});
	}

	public function addChatMessageListener(handler:ChatMessage->Void):Void {
		chatMessageHandlers.push(handler);
	}

	private function onConnected(data) {
		if (data != null && data.jid != null) {
			final jidp = JID.parse(data.jid);
			if (!jidp.isBare()) persistence.storeLogin(jidp.asBare().asString(), jidp.resource, null);
		}
		this.stream.on("message", function(event) {
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

			final chatMessage = ChatMessage.fromStanza(stanza, jid);
			if (chatMessage != null) {
				var chat = getDirectChat(chatMessage.conversation());
				chatActivity(chat);
				for (handler in chatMessageHandlers) {
					handler(chatMessage);
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

			return EventUnhandled; // Allow others to get this event as well
		});

		this.stream.on("iq", function(event) {
			final stanza:Stanza = event.stanza;
			final from = stanza.attr.get("from") == null ? null : JID.parse(stanza.attr.get("from"));

			final jingle = stanza.getChild("jingle", "urn:xmpp:jingle:1");
			if (stanza.attr.get("type") == "set" && jingle != null) {
				// First, jingle requires useless replies to every iq
				sendStanza(new Stanza("iq", { type: "result", to: stanza.attr.get("from"), id: stanza.attr.get("id") }));
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
						chat.jingleSessions.set(session.sid, newSession);
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
				return EventHandled;
			}

			if (stanza.attr.get("type") == "get" && stanza.getChild("query", "http://jabber.org/protocol/disco#info") != null) {
				stream.sendStanza(caps.discoReply(stanza));
				return EventHandled;
			}

			if (
				stanza.attr.get("from") != null &&
				stanza.attr.get("from") != JID.parse(jid).domain
			) {
				return EventUnhandled;
			}

			var roster = new RosterGet();
			roster.handleResponse(stanza);
			var items = roster.getResult();
			if (items.length == 0) return EventUnhandled;

			for (item in items) {
				if (item.subscription != "remove") {
					final chat = getDirectChat(item.jid, false);
					chat.setTrusted(item.subscription == "both" || item.subscription == "from");
				}
			}
			this.trigger("chats/update", chats);

			var reply = new Stanza("iq", {
				type: "result",
				id: stanza.attr.get("id"),
				to: stanza.attr.get("from")
			});
			sendStanza(reply);

			return EventHandled;
		});

		this.stream.on("presence", function(event) {
			final stanza:Stanza = event.stanza;
			final c = stanza.getChild("c", "http://jabber.org/protocol/caps");
			if (c != null && stanza.attr.get("from") != null) {
				final chat = getDirectChat(JID.parse(stanza.attr.get("from")).asBare().asString(), false);
				persistence.getCaps(c.attr.get("ver"), (caps) -> {
					if (caps == null) {
						final discoGet = new DiscoInfoGet(stanza.attr.get("from"), c.attr.get("node") + "#" + c.attr.get("ver"));
						discoGet.onFinished(() -> {
							if (discoGet.getResult() != null) {
								persistence.storeCaps(discoGet.getResult());
								chat.setCaps(JID.parse(stanza.attr.get("from")).resource, discoGet.getResult());
							}
						});
						sendQuery(discoGet);
					} else {
						chat.setCaps(JID.parse(stanza.attr.get("from")).resource, caps);
					}
				});
				return EventHandled;
			}

			return EventUnhandled;
		});

		// Enable carbons
		stream.sendStanza(
			new Stanza("iq", { type: "set", id: ID.short() })
				.tag("enable", { xmlns: "urn:xmpp:carbons:2" })
				.up()
		);

		rosterGet();
		sync(() -> {
			// Set self to online
			sendPresence();
			this.trigger("status/online", {});
		});

		return EventHandled;
	}

	public function usePassword(password: String):Void {
		this.stream.trigger("auth/password", { password: password });
	}

	/* Return array of chats, sorted by last activity */
	public function getChats():ChatList {
		return chats;
	}

	public function getDirectChat(chatId:String, triggerIfNew:Bool = true):DirectChat {
		for (chat in chats) {
			if (Std.isOfType(chat, DirectChat) && chat.chatId == chatId) {
				return Std.downcast(chat, DirectChat);
			}
		}
		var chat = new DirectChat(this, this.stream, this.persistence, chatId);
		chats.unshift(chat);
		if (triggerIfNew) this.trigger("chats/update", [chat]);
		return chat;
	}

	public function findAvailableChats(q:String, callback:(q:String, chatIds:Array<String>) -> Void) {
		var results = [];
		final query = StringTools.trim(q);
		final jid = JID.parse(query);
		if (jid.isValid()) {
			results.push(jid.asBare().asString());
			callback(q, results); // send some right away
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
								results.push(new JID(query, bareJid.domain).asString());
								callback(q, results);
							} else if (bareJid.isDomain()) {
								results.push(new JID(StringTools.replace(query, "@", "%"), bareJid.domain).asString());
								callback(q, results);
							}
						} else {
							switch (jigGet.getResult()) {
								case Left(error): return;
								case Right(result):
									results.push(result);
									callback(q, results);
							}
						}
					});
					sendQuery(jigGet);
				}
			}
		}
	}

	public function chatActivity(chat: Chat) {
		var idx = chats.indexOf(chat);
		if (idx > 0) {
			chats.splice(idx, 1);
			chats.unshift(chat);
			this.trigger("chats/update", []);
		}
	}

	/* Internal-ish methods */
	public function sendQuery(query:GenericQuery) {
		this.stream.sendIq(query.getQueryStanza(), query.handleResponse);
	}

	public function sendStanza(stanza:Stanza) {
		stream.sendStanza(stanza);
	}

	public function sendPresence(?to: String) {
		sendStanza(caps.addC(new Stanza("presence", to == null ? {} : { to: to })));
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
			}
			this.trigger("chats/update", chats);
		});
		sendQuery(rosterGet);
	}

	private function sync(?callback: ()->Void) {
		persistence.lastId(jid, null, (lastId) -> doSync(callback, lastId));
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
