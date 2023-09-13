package xmpp;

import haxe.crypto.Base64;
import haxe.io.Bytes;
import haxe.io.BytesData;
import xmpp.Chat;
import xmpp.EventEmitter;
import xmpp.Stream;
import xmpp.queries.GenericQuery;
import xmpp.queries.RosterGet;
import xmpp.queries.PubsubGet;
import xmpp.PubsubEvent;

typedef ChatList = Array<Chat>;

@:expose
class Client extends xmpp.EventEmitter {
	private var stream:GenericStream;
	private var chatMessageHandlers: Array<(ChatMessage)->Void> = [];
	public var jid(default,null):String;
	private var chats: ChatList = [];
	private var persistence: Persistence;

	public function new(jid: String, persistence: Persistence) {
		super();
		this.jid = jid;
		this.persistence = persistence;
		stream = new Stream();
		stream.on("status/online", this.onConnected);
		stream.on("auth/password-needed", (data)->this.trigger("auth/password-needed", { jid: this.jid }));
	}

	public function start() {
		stream.connect(jid);
	}

	public function addChatMessageListener(handler:ChatMessage->Void):Void {
		chatMessageHandlers.push(handler);
	}

	private function onConnected(data) {
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
				final avatarSha1Hex = pubsubEvent.getItems()[0].attr.get("id");
				final avatarSha1 = Bytes.ofHex(avatarSha1Hex).getData();
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
							persistence.storeMedia(Base64.decode(dataNode.getText()).getData(), () -> {
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
				stream.sendStanza(
					new Stanza("iq", {
						type: "result",
						id: stanza.attr.get("id"),
						to: stanza.attr.get("from")
					})
						.tag("query", { xmlns: "http://jabber.org/protocol/disco#info" })
						.tag("feature", { "var": "urn:xmpp:avatar:metadata+notify"}).up()
						.up()
				);
				return EventHandled;
			}

			return EventUnhandled;
		});

		stream.sendStanza(new Stanza("presence")); // Set self to online
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
				getDirectChat(item.jid, false);
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
