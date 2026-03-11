package test;

import utest.Assert;
import utest.Async;

import borogove.Client;
import borogove.Stanza;
import borogove.persistence.Dummy;

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
}
