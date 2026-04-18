package test;

import thenshim.Promise;
import utest.Assert;
import utest.Async;

import borogove.Chat;
import borogove.ChatMessage;
import borogove.ChatMessageBuilder;
import borogove.Client;
import borogove.JID;
import borogove.Message;
import borogove.Stanza;
import borogove.persistence.Dummy;

using Lambda;

@:access(borogove)
class TestClient extends utest.Test {
	public function testAccountId() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		Assert.equals("test@example.com", client.accountId());
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
