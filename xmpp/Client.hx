package xmpp;

import haxe.crypto.Base64;
import haxe.io.Bytes;
import haxe.io.BytesData;
import xmpp.Caps;
import xmpp.Chat;
import xmpp.EventEmitter;
import xmpp.Stream;
import xmpp.queries.GenericQuery;
import xmpp.queries.RosterGet;
import xmpp.queries.PubsubGet;
import xmpp.queries.DiscoInfoGet;
import xmpp.queries.JabberIqGatewayGet;
import xmpp.PubsubEvent;

typedef ChatList = Array<Chat>;

@:expose
class Client extends xmpp.EventEmitter {
	private var stream:GenericStream;
	private var chatMessageHandlers: Array<(ChatMessage)->Void> = [];
	public var jid(default,null):String;
	private var chats: ChatList = [];
	private var persistence: Persistence;
	private final caps = new Caps("https://sdk.snikket.org", [], ["urn:xmpp:avatar:metadata+notify"]);

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
				final chat = getDirectChat(stanza.attr.get("from"), false);
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

		// Set self to online
		stream.sendStanza(caps.addC(new Stanza("presence")));

		// Enable carbons
		stream.sendStanza(
			new Stanza("iq", { type: "set", id: ID.short() })
				.tag("enable", { xmlns: "urn:xmpp:carbons:2" })
				.up()
		);

		rosterGet();
		sync();
		return this.trigger("status/online", {});
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

	private function sync() {
		var thirtyDaysAgo = Date.format(
			DateTools.delta(std.Date.now(), DateTools.days(-30))
		);
		persistence.lastId(jid, null, function(lastId) {
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
				if (sync.hasMore()) sync.fetchNext();
			});
			sync.fetchNext();
		});
	}
}
