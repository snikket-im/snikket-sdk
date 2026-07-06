package test;

import thenshim.Promise;
import utest.Assert;
import utest.Async;

import borogove.Chat;
import borogove.ChatMessage;
import borogove.ChatMessageBuilder;
import borogove.Client;
import borogove.JID;
import borogove.Member;
import borogove.MemberUpdate;
import borogove.Message;
import borogove.ModerationAction;
import borogove.Role;
import borogove.Stanza;
import borogove.Status;
import borogove.persistence.Dummy;
import borogove.Chat.OutgoingE2EEPreference;

using Lambda;

@:access(borogove)
class TestClient extends utest.Test {
	public function testSetStatus(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			final s = stanza.toString();
			if (stanza.name == "iq" && s.indexOf("http://jabber.org/protocol/activity") != -1) {
				Assert.isTrue(s.indexOf("😊") != -1);
				Assert.isTrue(s.indexOf("feeling good") != -1);
				async.done();
				return EventHandled;
			}
			return EventUnhandled;
		});

		client.setStatus(new Status("😊", "feeling good"));
	}

	public function testReceiveStatusUpdate(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final friendJid = "friend@example.com";
		client.getDirectChat(friendJid);

		client.addChatsUpdatedListener(chats -> {
			final friendChat = chats.find(c -> c.chatId == friendJid);
			if (friendChat != null && friendChat.status.text == "working hard") {
				Assert.equals("💻", friendChat.status.emoji);
				Assert.equals("working hard", friendChat.status.text);
				async.done();
			}
		});

		client.stream.onStanza(
			new Stanza("message", { xmlns: "jabber:client", from: friendJid })
				.tag("event", { xmlns: "http://jabber.org/protocol/pubsub#event" })
				.tag("items", { node: "http://jabber.org/protocol/activity" })
				.tag("item")
				.tag("activity", { xmlns: "http://jabber.org/protocol/activity" })
					.textTag("text", "working hard")
					.tag("undefined")
						.textTag("emoji", "💻", { xmlns: "https://ns.borogove.dev/" })
		);
	}

	public function testPresenceIncludesStatus() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = client.getDirectChat("test@example.com");
		chat.status = new Status("🚀", "zooming");

		var presenceSent = false;
		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "presence" && stanza.attr.get("to") == null) {
				Assert.equals("🚀 zooming", stanza.getChildText("status"));
				presenceSent = true;
				return EventHandled;
			}
			return EventUnhandled;
		});

		client.sendPresence();
		Assert.isTrue(presenceSent);
	}

	public function testAccountId() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		Assert.equals("test@example.com", client.accountId());
	}

	public function testModerateMessage(async: Async) {
		final persistence = new MessageMockPersistence();
		final client = new Client("test@example.com", persistence);
		final chatId = "chat@example.com";
		final serverId = "msg123";

		// Pre-populate persistence with a message
		final builder = new ChatMessageBuilder();
		builder.serverId = serverId;
		builder.from = JID.parse("other@example.com");
		builder.to = JID.parse("test@example.com");
		builder.senderId = "other@example.com";
		builder.text = "to be moderated";
		final originalMessage = builder.build();

		persistence.storeMessages(client.accountId(), [originalMessage]).then((_) -> {
			final action = new ModerationAction(chatId, serverId, "2023-01-01T00:00:00Z", "mod@example.com", "Spam");

			client.moderateMessage(action).then((moderatedMessage) -> {
				Assert.notNull(moderatedMessage);
				Assert.equals("Spam", moderatedMessage.moderationReason());
				async.done();
			});
		});
	}

	public function testModerateMessageNoReason(async: Async) {
		final persistence = new MessageMockPersistence();
		final client = new Client("test@example.com", persistence);
		final chatId = "chat@example.com";
		final serverId = "msg124";

		// Pre-populate persistence with a message
		final builder = new ChatMessageBuilder();
		builder.serverId = serverId;
		builder.from = JID.parse("other@example.com");
		builder.to = JID.parse("test@example.com");
		builder.senderId = "other@example.com";
		builder.text = "to be moderated";
		final originalMessage = builder.build();

		persistence.storeMessages(client.accountId(), [originalMessage]).then((_) -> {
			final action = new ModerationAction(chatId, serverId, "2023-01-01T00:00:00Z", "mod@example.com", null);

			client.moderateMessage(action).then((moderatedMessage) -> {
				Assert.notNull(moderatedMessage);
				Assert.equals("moderated", moderatedMessage.moderationReason());
				async.done();
			});
		});
	}

	public function testDecryptionFailurePreservesLocalMessage(async: Async) {
		final persistence = new MessageMockPersistence();
		final client = new Client("test@example.com", persistence);
		final chatId = "chat@example.com";
		client.getDirectChat(chatId);

		final localBuilder = new ChatMessageBuilder({
			localId: "local-123",
			text: "good original text",
			direction: MessageSent,
			senderId: "test@example.com",
			status: MessagePending
		});
		localBuilder.to = JID.parse(chatId);
		final localMessage = localBuilder.build();

		persistence.storeMessages(client.accountId(), [localMessage]).then(_ -> {
			final incomingBuilder = new ChatMessageBuilder({
				localId: "local-123",
				serverId: "server-456",
				serverIdBy: "server.com",
				syncPoint: true,
				direction: MessageSent,
				senderId: "test@example.com",
				status: MessageDeliveredToServer,
				encryption: new borogove.EncryptionInfo(DecryptionFailure, "omemo"),
				text: "failed decryption fallback"
			});
			incomingBuilder.sortId = "sort-1";
			incomingBuilder.to = JID.parse(chatId);

			client.storeMessages([incomingBuilder.build()]).then(stored -> {
				Assert.equals(1, stored.length);
				final m = stored[0];
				Assert.equals("server-456", m.serverId);
				Assert.equals("server.com", m.serverIdBy);
				Assert.isTrue(m.syncPoint);
				Assert.equals("sort-1", m.sortId);
				Assert.equals(MessageDeliveredToServer, m.status);
				Assert.equals("good original text", m.text);
				async.done();
			});
		});
	}

	public function testDefaultDisplayName() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		Assert.equals("test", client.displayName());
	}

	public function testDefaultDisplayNameDomain() {
		final persistence = new Dummy();
		final client = new Client("example.com", persistence);
		Assert.equals("example.com", client.displayName());
	}

	public function testDisplayNameFromServer() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		Assert.equals("test", client.displayName());
		client.stream.onStanza(
			new Stanza("message", { xmlns: "jabber:client", from: "test@example.com" })
				.tag("event", { xmlns: "http://jabber.org/protocol/pubsub#event" })
				.tag("items", { node: "http://jabber.org/protocol/nick" })
				.tag("item")
				.textTag("nick", "Test Name", { xmlns: "http://jabber.org/protocol/nick" })
		);
		Assert.equals("Test Name", client.displayName());
	}

	public function testSortAfterDirectChat() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final pinned = client.getDirectChat("pinned@example.com");
		pinned.togglePinned();
		client.getDirectChat("notpinned@example.com");
		Assert.equals(2, client.chats.length);
		Assert.equals(pinned, client.chats[0]);
		Assert.equals(pinned, client.getChats()[0]);
	}

	public function testStart(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);

		// When we try to connect, just say we're online right away
		client.stream.on("connect", (data) -> {
			client.stream.trigger("status/online", { jid: data.jid });

			return EventHandled;
		});

		// When we send an iq, reply with an error
		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "iq") {
				client.stream.onStanza(new Stanza("iq", { xmlns: "jabber:client", type: "error", id: stanza.attr.get("id") }));
			}

			return EventHandled;
		});

		client.addStatusOnlineListener(() -> {
			Assert.isTrue(client.inSync);
			async.done();
		});

		client.start();
	}

	public function testUsePassword(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);

		// When we try to connect, we need a password
		client.stream.on("connect", (data) -> {
			client.stream.trigger("auth/password-needed", { mechanisms: [{ name: "SCRAM-SHA-1", canFast: false, canOther: true }] });

			return EventHandled;
		});

		// When we get the right password, then we are online
		client.stream.on("auth/password", (data) -> {
			Assert.equals("password", data.password);
			Assert.equals(null, data.requestToken);
			client.stream.trigger("status/online", {});

			return EventHandled;
		});

		// When we send an iq, reply with an error
		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "iq") {
				client.stream.onStanza(new Stanza("iq", { xmlns: "jabber:client", type: "error", id: stanza.attr.get("id") }));
			}

			return EventHandled;
		});

		client.addStatusOnlineListener(() -> {
			Assert.isTrue(client.inSync);
			async.done();
		});

		client.addPasswordNeededListener(account -> {
			client.usePassword("password");
		});

		client.start();
	}

	public function testUsePasswordRequestToken(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);

		// When we try to connect, we need a password
		client.stream.on("connect", (data) -> {
			client.stream.trigger("auth/password-needed", {
				mechanisms: [
					{ name: "SCRAM-SHA-1", canFast: false, canOther: true },
					{ name: "FASTMECH", canFast: true, canOther: false }
				]
			});

			return EventHandled;
		});

		// When we get the right password, then we are online
		client.stream.on("auth/password", (data) -> {
			Assert.equals("password", data.password);
			Assert.equals("FASTMECH", data.requestToken);
			client.stream.trigger("status/online", {});

			return EventHandled;
		});

		// When we send an iq, reply with an error
		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "iq") {
				client.stream.onStanza(new Stanza("iq", { xmlns: "jabber:client", type: "error", id: stanza.attr.get("id") }));
			}

			return EventHandled;
		});

		client.addStatusOnlineListener(() -> {
			Assert.isTrue(client.inSync);
			async.done();
		});

		client.addPasswordNeededListener(account -> {
			client.usePassword("password");
		});

		client.start();
	}

	public function testNewMessageNewChat(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);

		var gotMessage = false;

		client.addChatMessageListener((message, event) -> {
			Assert.equals("localid", message.localId);
			Assert.equals("hi", message.text);
			Assert.equals(DeliveryEvent, event);
			gotMessage = true;
		});

		client.addChatsUpdatedListener(chats -> {
			Assert.equals(1, chats.length);
			Assert.equals(1, client.getChats().length);
			Assert.equals("test2@example.com", chats[0].chatId);
			Assert.equals("localid", chats[0].lastMessage.localId);
			Assert.isTrue(gotMessage);
			async.done();
		});

		client.stream.onStanza(new Stanza("message", { xmlns: "jabber:client", from: "test2@example.com", id: "localid"}).textTag("body", "hi"));
	}

	public function testEmptyAccountId() {
		final persistence = new Dummy();
		Assert.raises(() -> new Client("", persistence), String);
		Assert.raises(() -> new Client(null, persistence), String);
	}

	public function testGetChatsFilter() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat1 = client.getDirectChat("test1@example.com");
		final chat2 = client.getDirectChat("test2@example.com");

		Assert.equals(2, client.getChats().length);

		chat1.close();
		Assert.equals(1, client.getChats().length);
		Assert.equals("test2@example.com", client.getChats()[0].chatId);
	}

	public function testChatsUpdateEvent(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		client.on("chats/update", (chats: Array<Chat>) -> {
			final friendChat = chats.find(c -> c.chatId == "friend@example.com");
			if (friendChat != null) {
				Assert.equals("friend@example.com", friendChat.chatId);
				async.done();
			}
			return EventHandled;
		});

		client.getDirectChat("friend@example.com");
	}

	public function testPresenceSubscription(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		client.inSync = true;

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "iq" && stanza.findChild("{http://jabber.org/protocol/disco#info}query") != null) {
				client.stream.onStanza(
					new Stanza("iq", { type: "result", to: "test@example.com", id: stanza.attr.get("id"), from: "stranger@example.com", xmlns: "jabber:client" })
						.tag("query", { xmlns: "http://jabber.org/protocol/disco#info" })
							.tag("identity", { category: "client", type: "pc", name: "Stranger" }).up()
						.up()
				);
			}
			return EventHandled;
		});

		client.on("chats/update", (chats: Array<Chat>) -> {
			final strangerChat = chats.find(c -> c.chatId == "stranger@example.com");
			if (strangerChat != null && strangerChat.uiState == Invited) {
				Assert.equals("stranger@example.com", strangerChat.chatId);
				Assert.equals("Stranger (stranger@example.com)", strangerChat.getDisplayName());
				Assert.equals(Invited, strangerChat.uiState);
				async.done();
			}
			return EventHandled;
		});

		client.stream.onStanza(
			new Stanza("presence", { from: "stranger@example.com", type: "subscribe", xmlns: "jabber:client" })
				.textTag("nick", "Stranger", { xmlns: "http://jabber.org/protocol/nick" })
		);
	}

	public function testHandleReceipt(async: Async) {
		final persistence = new MockPersistence();
		final client = new Client("test@example.com", persistence);

		client.on("message/new", (data: { message: ChatMessage, event: ChatMessageEvent }) -> {
			if (data.event == StatusEvent) {
				Assert.equals("msg-id", data.message.localId);
				Assert.equals(MessageDeliveredToDevice, data.message.status);
				async.done();
			}
			return EventHandled;
		});

		final receiptStanza = new Stanza("message", { xmlns: "jabber:client", from: "bob@example.com", to: "test@example.com" })
			.tag("received", { xmlns: "urn:xmpp:receipts", id: "msg-id" }).up();

		client.stream.onStanza(receiptStanza);
	}

	public function testHandleReceiptInSync(async: Async) {
		final persistence = new MockPersistence();
		final client = new Client("test@example.com", persistence);

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			final query = stanza.findChild("{urn:xmpp:mam:2}query");
			if (stanza.name == "iq" && query != null) {
				final queryId = query.attr.get("queryid");

				final receiptStanza = new Stanza("message", { xmlns: "jabber:client", from: "bob@example.com", to: "test@example.com" })
					.tag("received", { xmlns: "urn:xmpp:receipts", id: "msg-id" }).up();

				final mamResult = new Stanza("message", { xmlns: "jabber:client", to: "test@example.com", from: "test@example.com" })
					.tag("result", { xmlns: "urn:xmpp:mam:2", queryid: queryId, id: "mam-id-1" })
						.tag("forwarded", { xmlns: "urn:xmpp:forward:0" })
							.tag("delay", { xmlns: "urn:xmpp:delay", stamp: "2023-01-01T00:00:00Z" }).up()
							.addChild(receiptStanza)
						.up()
					.up();

				client.stream.onStanza(mamResult);

				final finishedIq = new Stanza("iq", { xmlns: "jabber:client", type: "result", id: stanza.attr.get("id"), from: "test@example.com" })
					.tag("fin", { xmlns: "urn:xmpp:mam:2", complete: "true" })
						.tag("set", { xmlns: "http://jabber.org/protocol/rsm" })
						.up()
					.up();
				client.stream.onStanza(finishedIq);
			}
			return EventHandled;
		});

		client.on("message/new", (data: { message: ChatMessage, event: ChatMessageEvent }) -> {
			if (data.event == StatusEvent) {
				Assert.equals("msg-id", data.message.localId);
				Assert.equals(MessageDeliveredToDevice, data.message.status);
			}
			return EventHandled;
		});

		client.doSync((_) -> {
			Assert.equals(MessageDeliveredToDevice, persistence.statusUpdates.get("msg-id"));
			async.done();
		}, null);
	}

	public function testSendReceipt(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		client.getDirectChat("bob@example.com").setTrusted(true);

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "message" && stanza.getChild("received", "urn:xmpp:receipts") != null) {
				Assert.equals("bob@example.com", stanza.attr.get("to"));
				Assert.equals("msg123", stanza.getChild("received", "urn:xmpp:receipts").attr.get("id"));
				async.done();
				return EventHandled;
			}
			return EventUnhandled;
		});

		client.stream.onStanza(new Stanza("message", { xmlns: "jabber:client", from: "bob@example.com", id: "msg123" }).textTag("body", "hello"));
	}

	public function testSendReceiptSync(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		client.getDirectChat("bob@example.com").setTrusted(true);

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "message" && stanza.getChild("received", "urn:xmpp:receipts") != null) {
				Assert.equals("bob@example.com", stanza.attr.get("to"));
				Assert.equals("sync123", stanza.getChild("received", "urn:xmpp:receipts").attr.get("id"));
				async.done();
				return EventHandled;
			}
			return EventUnhandled;
		});

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "iq" && stanza.findChild("{urn:xmpp:mam:2}query") != null) {
				final queryId = stanza.findChild("{urn:xmpp:mam:2}query").attr.get("queryid");
				final mamResult = new Stanza("message", { xmlns: "jabber:client", to: "test@example.com", from: "test@example.com" })
					.tag("result", { xmlns: "urn:xmpp:mam:2", queryid: queryId, id: "mam-id-1" })
						.tag("forwarded", { xmlns: "urn:xmpp:forward:0" })
							.tag("delay", { xmlns: "urn:xmpp:delay", stamp: "2023-01-01T00:00:00Z" }).up()
							.tag("message", { xmlns: "jabber:client", from: "bob@example.com", id: "sync123" })
								.textTag("body", "sync message")
							.up()
						.up()
					.up();

				client.stream.onStanza(mamResult);

				final finishedIq = new Stanza("iq", { xmlns: "jabber:client", type: "result", id: stanza.attr.get("id"), from: "test@example.com" })
					.tag("fin", { xmlns: "urn:xmpp:mam:2", complete: "true" })
						.tag("set", { xmlns: "http://jabber.org/protocol/rsm" })
						.up()
					.up();
				client.stream.onStanza(finishedIq);
				return EventHandled;
			}
			return EventUnhandled;
		});

		client.doSync((_) -> {}, null);
	}

	public function testMucAffiliationMessageStoresMemberUpdatesAndEmits(async: Async) {
		final persistence = new MemberUpdateMockPersistence();
		final client = new Client("test@example.com", persistence);
		final chat = new borogove.Chat.Channel(client, client.stream, persistence, "room@example.com");
		client.chats.push(chat);
		var onPersistedEvent = null;
		final afterPersistedEvent = new Promise((resolved, rejected) -> { onPersistedEvent = resolved; });

		chat.addMembersUpdatedListener((members) -> {
			if (persistence.lastUpdates.length > 0) {
				Assert.equals(1, members.length);
				Assert.equals("room@example.com/occ-1", members[0].id);
				Assert.equals("alice@example.com", members[0].chat.chatId);
				onPersistedEvent(null);
			}
		});

		client.stream.onStanza(Stanza.parse('<message from="room@example.com" xmlns="jabber:client">
			<x xmlns="http://jabber.org/protocol/muc#user">
				<item affiliation="admin" jid="alice@example.com" nick="Alice">
					<occupant-id xmlns="urn:xmpp:occupant-id:0" id="occ-1" />
				</item>
			</x>
		</message>'));

		afterPersistedEvent.then(_ -> {
			Assert.equals(false, persistence.lastIsFullList);
			Assert.equals("room@example.com", persistence.lastChatId);
			Assert.equals(1, persistence.lastUpdates.length);
			if (persistence.lastUpdates.length > 0) {
				Assert.equals("room@example.com/occ-1", persistence.lastUpdates[0].id);
			}
			async.done();
		});
	}

	public function testMucAffiliationFullListSetsFlag(async: Async) {
		final persistence = new MemberUpdateMockPersistence();
		final client = new Client("test@example.com", persistence);
		final chat = new borogove.Chat.Channel(client, client.stream, persistence, "room@example.com");
		client.chats.push(chat);

		client.stream.onStanza(Stanza.parse('<message from="room@example.com" xmlns="jabber:client">
			<x xmlns="http://jabber.org/protocol/muc#user">
				<mav xmlns="urn:xmpp:muc:affiliations:1" until="v2" />
				<item affiliation="admin" jid="alice@example.com" nick="Alice">
					<occupant-id xmlns="urn:xmpp:occupant-id:0" id="occ-1" />
				</item>
			</x>
		</message>'));

		haxe.Timer.delay(() -> {
			Assert.equals(true, persistence.lastIsFullList);
			Assert.equals("v2", chat.mavUntil);
			async.done();
		}, 1);
	}

	public function testConnectClearsMemberPresence(async: Async) {
		final persistence = new MemberUpdateMockPersistence();
		final client = new Client("test@example.com", persistence);

		client.stream.on("connect", (data) -> {
			client.stream.trigger("status/online", { jid: "test@example.com/resource" });
			return EventHandled;
		});

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "iq") {
				client.stream.onStanza(new Stanza("iq", { xmlns: "jabber:client", type: "error", id: stanza.attr.get("id") }));
			}
			return EventHandled;
		});

		client.addStatusOnlineListener(() -> {
			Assert.equals(1, persistence.clearMemberPresenceCalls.length);
			Assert.equals("test@example.com", persistence.clearMemberPresenceCalls[0].accountId);
			Assert.isNull(persistence.clearMemberPresenceCalls[0].chatId);
			async.done();
		});

		client.start();
	}

	public function testMucVoiceRequest(async: Async) {
		final persistence = new VoiceRequestMockPersistence();
		final client = new Client("test@example.com", persistence);
		final chat = new borogove.Chat.Channel(client, client.stream, persistence, "room@example.com");
		client.chats.push(chat);

		var onPersistedEvent = null;
		final afterPersistedEvent = new Promise((resolved, rejected) -> { onPersistedEvent = resolved; });

		client.on("chats/update", (chats: Array<Chat>) -> {
			final c = chats.find(x -> x.chatId == "room@example.com");
			if (c != null && persistence.lastVoiceRequests.length > 0) {
				onPersistedEvent(null);
			}
			return EventHandled;
		});

		final stanza = Stanza.parse('<message from="room@example.com" xmlns="jabber:client">
			<x xmlns="jabber:x:data" type="form">
				<field var="FORM_TYPE"><value>http://jabber.org/protocol/muc#request</value></field>
				<field var="muc#role"><value>participant</value></field>
				<field var="muc#jid"><value>requester@example.com</value></field>
			</x>
		</message>');

		client.stream.onStanza(stanza);

		afterPersistedEvent.then(_ -> {
			Assert.equals(1, persistence.lastVoiceRequests.length);
			Assert.equals("test@example.com", persistence.lastVoiceRequests[0].accountId);
			Assert.equals("room@example.com", persistence.lastVoiceRequests[0].chat.chatId);
			Assert.equals("requester@example.com", persistence.lastVoiceRequests[0].jid);
			Assert.equals(true, persistence.lastVoiceRequests[0].requesting);
			async.done();
		});
	}

	public function testPreferE2ee() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		client.outgoingE2EEPreference = [];
		client.preferE2ee(OutgoingE2EEPreference.NoE2EE);
		Assert.equals(OutgoingE2EEPreference.NoE2EE, client.outgoingE2EEPreference[0]);
	}

	public function testBanE2ee() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		client.banE2ee(OutgoingE2EEPreference.NoE2EE);
		Assert.isFalse(client.outgoingE2EEPreference.contains(OutgoingE2EEPreference.NoE2EE));
	}

	public function testBlockIncomingWithoutE2EE(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		client.blockIncomingWithoutE2EE = true;

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "message" && stanza.attr.get("type") == "error") {
				Assert.equals("friend@example.com", stanza.attr.get("to"));
				final error = stanza.getChild("error");
				Assert.notNull(error);
				Assert.equals("cancel", error.attr.get("type"));
				Assert.notNull(error.getChild("policy-violation", "urn:ietf:params:xml:ns:xmpp-stanzas"));
				async.done();
				return EventHandled;
			}
			return EventUnhandled;
		});

		client.stream.onStanza(
			new Stanza("message", { xmlns: "jabber:client", from: "friend@example.com", id: "msg1" })
				.textTag("body", "hello without e2ee")
		);
	}

#if js
	public function testPreferOMEMO() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		client.preferE2ee(OutgoingE2EEPreference.OMEMO);
		Assert.equals(OutgoingE2EEPreference.OMEMO, client.outgoingE2EEPreference[0]);
	}
#end
}

@:access(borogove)
class MockPersistence extends Dummy {
	public var statusUpdates: Map<String, MessageStatus> = [];
	public function new() { super(); }

	override public function updateMessageStatus(accountId: String, localId: String, status:MessageStatus, statusText: Null<String>): Promise<ChatMessage> {
		statusUpdates.set(localId, status);
		final builder = new ChatMessageBuilder();
		builder.localId = localId;
		builder.status = status;
		builder.from = JID.parse("bob@example.com");
		builder.to = JID.parse(accountId);
		builder.senderId = "bob@example.com";
		builder.replyTo = [JID.parse("bob@example.com")];
		return Promise.resolve(builder.build());
	}
}

@:access(borogove)
class MessageMockPersistence extends Dummy {
	public var messages: Map<String, ChatMessage> = [];
	public function new() { super(); }

	override public function storeMessages(accountId: String, messages: Array<ChatMessage>): Promise<Array<ChatMessage>> {
		for (m in messages) {
			if (m.serverId != null) this.messages.set(m.serverId, m);
			if (m.localId != null) this.messages.set(m.localId, m);
		}
		return Promise.resolve(messages);
	}

	override public function getMessage(accountId: String, chatId: String, serverId: Null<String>, localId: Null<String>): Promise<Null<ChatMessage>> {
		if (serverId != null && messages.exists(serverId)) return Promise.resolve(messages.get(serverId));
		if (localId != null && messages.exists(localId)) return Promise.resolve(messages.get(localId));
		return Promise.resolve(null);
	}

	override public function updateMessage(accountId: String, message: ChatMessage) {
		if (message.serverId != null) this.messages.set(message.serverId, message);
	}
}

@:access(borogove)
class MemberUpdateMockPersistence extends Dummy {
	public var lastUpdates: Array<MemberUpdate> = [];
	public var lastIsFullList: Null<Bool> = null;
	public var lastChatId: Null<String> = null;
	public var clearMemberPresenceCalls: Array<{ accountId: String, chatId: Null<String> }> = [];

	override public function storeMemberUpdates(accountId: String, chat: Chat, updates: Array<MemberUpdate>, isFullList: Bool) {
		lastUpdates = updates;
		lastIsFullList = isFullList;
		lastChatId = chat.chatId;
		return Promise.resolve([
			new Member(
				"room@example.com/occ-1",
				"Alice",
				null,
				false,
				[Role.forAffiliation("admin")],
				JID.parse("alice@example.com"),
				new Map(),
				new borogove.Chat.AvailableChat("alice@example.com", "Alice", "", borogove.CapsRepo.empty)
			)
		]);
	}

	override public function clearMemberPresence(accountId: String, chatId: Null<String>) {
		clearMemberPresenceCalls.push({ accountId: accountId, chatId: chatId });
		return Promise.resolve(true);
	}
}

@:access(borogove)
class VoiceRequestMockPersistence extends Dummy {
	public var lastVoiceRequests: Array<{ accountId: String, chat: Chat, jid: String, requesting: Bool }> = [];

	override public function storeVoiceRequest(accountId: String, chat: Chat, jid: String, requesting: Bool): Promise<Bool> {
		lastVoiceRequests.push({ accountId: accountId, chat: chat, jid: jid, requesting: requesting });
		return Promise.resolve(true);
	}
}
