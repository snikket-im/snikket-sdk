package test;

import thenshim.Promise;
import utest.Assert;
import utest.Async;

import borogove.Client;
import borogove.Caps;
import borogove.Stanza;
import borogove.Chat;
import borogove.ChatMessage;
import borogove.ChatMessageBuilder;
import borogove.MessageSync;
import borogove.persistence.Dummy;

using Lambda;

@:access(borogove)
class TestSortId extends utest.Test {
	public function testDirectChatOutgoingSequence() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat1 = client.getDirectChat("sort1@example.com");
		final chat2 = client.getDirectChat("sort2@example.com");

		final m1 = new ChatMessageBuilder();
		m1.text = "hi 1";
		chat1.sendMessage(m1);
		final s1 = client.sortId;

		final m2 = new ChatMessageBuilder();
		m2.text = "hi 2";
		chat2.sendMessage(m2);
		final s2 = client.sortId;

		final m3 = new ChatMessageBuilder();
		m3.text = "hi 3";
		chat1.sendMessage(m3);
		final s3 = client.sortId;

		Assert.isTrue(s1 < s2, "s1 < s2");
		Assert.isTrue(s2 < s3, "s2 < s3");
	}

	public function testChannelOutgoingSequence() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final channel = new Channel(client, client.stream, persistence, "sortchannel@example.com");
		channel.sortId = "a ";

		final cSortId = client.sortId;

		final m1 = new ChatMessageBuilder();
		m1.text = "hi 1";
		channel.sendMessage(m1);
		final s1 = channel.sortId;

		final m2 = new ChatMessageBuilder();
		m2.text = "hi 2";
		channel.sendMessage(m2);
		final s2 = channel.sortId;

		Assert.isTrue(s1 < s2, "s1 < s2");
		Assert.equals(cSortId, client.sortId);
	}

	public function testDirectChatIncomingSequence(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = client.getDirectChat("sortincoming1@example.com");

		var messagesSoFar = 0;
		var sortIdSoFar = "a ";
		client.addChatMessageListener((message, event) -> {
			Assert.isTrue(sortIdSoFar < message.sortId, "sortIdSoFar < message.sortId");
			sortIdSoFar = message.sortId;
			messagesSoFar++;
			if (messagesSoFar > 1) async.done();
		});

		client.stream.onStanza(new Stanza("message", { from: "sortincoming1@example.com", id: "m1", xmlns: "jabber:client" }).textTag("body", "hi 1"));
		final s1 = client.sortId;

		client.stream.onStanza(new Stanza("message", { from: "sortincoming1@example.com", id: "m2", xmlns: "jabber:client" }).textTag("body", "hi 2"));
		final s2 = client.sortId;

		Assert.isTrue(s1 < s2, "s1 < s2");
	}

	public function testChannelIncomingSequence(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final cSortId = client.sortId;
		final channel = new Channel(client, client.stream, persistence, "sortincomingchannel@example.com");
		channel.sortId = "a ";
		client.chats.push(channel);

		var messagesSoFar = 0;
		var sortIdSoFar = "a ";
		client.addChatMessageListener((message, event) -> {
			Assert.isTrue(sortIdSoFar < message.sortId, "sortIdSoFar < message.sortId");
			sortIdSoFar = message.sortId;
			messagesSoFar++;
			if (messagesSoFar > 1) async.done();
		});

		client.stream.onStanza(new Stanza("message", { from: "sortincomingchannel@example.com/user1", id: "m1", type: "groupchat", xmlns: "jabber:client" }).textTag("body", "hi 1"));
		final s1 = channel.sortId;

		client.stream.onStanza(new Stanza("message", { from: "sortincomingchannel@example.com/user2", id: "m2", type: "groupchat", xmlns: "jabber:client" }).textTag("body", "hi 2"));
		final s2 = channel.sortId;

		Assert.isTrue(s1 < s2, "s1 < s2");
		Assert.equals(cSortId, client.sortId);
	}

	public function testSyncInterpolation(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final stream = client.stream;

		var queryId = null;
		var iqId = null;

		stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "iq") {
				iqId = stanza.attr.get("id");
				queryId = stanza.findChild("{urn:xmpp:mam:2}query")?.attr?.get("queryid");
			}
			return EventHandled;
		});

		final sync = new MessageSync(client, stream, { with: "sync@example.com" }, "a ", "b00");
		sync.onMessages(list -> {
			Assert.equals(2, list.messages.length);
			final m1 = switch(list.messages[0].parsed) { case ChatMessageStanza(m): m; default: null; };
			final m2 = switch(list.messages[1].parsed) { case ChatMessageStanza(m): m; default: null; };

			Assert.isTrue("a " < m1.sortId, "\"a \" < m1.sortId");
			Assert.isTrue(m1.sortId < m2.sortId, "m1.sortId < m2.sortId");
			Assert.isTrue(m2.sortId < "b00", "m2.sortId < \"b00\"");
			Assert.isTrue(m1.timestamp < m2.timestamp, "m1.timestamp < m2.timestamp"); // fake fractional part
			async.done();
		});

		sync.fetchNext();

		Assert.notNull(queryId);

		stream.onStanza(new Stanza("message", { from: "test@example.com", xmlns: "jabber:client" })
			.tag("result", { xmlns: "urn:xmpp:mam:2", queryid: queryId, id: "mam1" })
				.tag("forwarded", { xmlns: "urn:xmpp:forward:0" })
					.tag("delay", { xmlns: "urn:xmpp:delay", stamp: "2023-01-01T00:00:00Z" }).up()
					.tag("message", { from: "sync@example.com", to: "test@example.com", xmlns: "jabber:client" })
						.textTag("body", "hi 1")
					.up()
				.up()
			.up()
		);

		stream.onStanza(new Stanza("message", { from: "test@example.com", xmlns: "jabber:client" })
			.tag("result", { xmlns: "urn:xmpp:mam:2", queryid: queryId, id: "mam2" })
				.tag("forwarded", { xmlns: "urn:xmpp:forward:0" })
					.tag("delay", { xmlns: "urn:xmpp:delay", stamp: "2023-01-01T00:00:00Z" }).up()
					.tag("message", { from: "sync@example.com", to: "test@example.com", xmlns: "jabber:client" })
						.textTag("body", "hi 2")
					.up()
				.up()
			.up()
		);

		stream.onStanza(new Stanza("iq", { type: "result", id: iqId, from: "test@example.com", xmlns: "jabber:client" })
			.tag("fin", { xmlns: "urn:xmpp:mam:2" })
				.tag("set", { xmlns: "http://jabber.org/protocol/rsm" })
					.textTag("last", "mam2")
				.up()
			.up()
		);
	}

	public function testMessageChannelPrivateSequence() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final channel = new Channel(client, client.stream, persistence, "channel@example.com");
		final chanSortId = channel.sortId;
		client.chats.push(channel);

		// MessageChannelPrivate is triggered when MessageChat has MUC user extension
		client.stream.onStanza(new Stanza("message", { from: "channel@example.com/user1", id: "pm1", xmlns: "jabber:client" })
			.textTag("body", "private hi")
			.tag("x", { xmlns: "http://jabber.org/protocol/muc#user" }).up()
		);
		final s1 = client.sortId;

		client.stream.onStanza(new Stanza("message", { from: "channel@example.com/user1", id: "pm2", xmlns: "jabber:client" })
			.textTag("body", "private hi 2")
			.tag("x", { xmlns: "http://jabber.org/protocol/muc#user" }).up()
		);
		final s2 = client.sortId;

		Assert.isTrue(s1 < s2, "s1 < s2");
		Assert.equals(chanSortId, channel.sortId);
	}

	public function testChannelLiveMessageDuringSync(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final disco = new Caps("", [], ["http://jabber.org/protocol/muc", "urn:xmpp:mam:2"], []);
		final channel = new Channel(client, client.stream, persistence, "syncchannel@example.com", Open, false, false, null, null, null, disco);
		client.chats.push(channel);

		var sortIdSoFar = "a ";
		var syncSortIdSoFar = "Z";
		var chatUpdates = 0;

		client.on("chats/update", (chats) -> {
			chatUpdates++;

			if (chatUpdates >= 3) {
				Assert.equals("live1", channel.lastMessage.localId);
				async.done();
			}

			return EventHandled;
		});

		client.addChatMessageListener((message, event) -> {
			Assert.isTrue(sortIdSoFar < message.sortId, "sortIdSoFar < message.sortId");
			sortIdSoFar = message.sortId;
			Assert.isTrue(syncSortIdSoFar < sortIdSoFar, "syncSortIdSoFar < sortIdSoFar");
		});

		client.addSyncMessageListener((message) -> {
			Assert.isTrue(syncSortIdSoFar < message.sortId, "syncSortIdSoFar < message.sortId");
			syncSortIdSoFar = message.sortId;
			Assert.isTrue(syncSortIdSoFar < sortIdSoFar, "syncSortIdSoFar < sortIdSoFar");
		});

		var queryId = null;
		var iqId = null;
		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "iq") {
				iqId = stanza.attr.get("id");
				queryId = stanza.findChild("{urn:xmpp:mam:2}query")?.attr?.get("queryid");
			}
			return EventHandled;
		});

		channel.join();

		Promise.resolve(null).then(_ -> {
			Assert.notNull(queryId);
			Assert.notNull(iqId);

			client.stream.onStanza(new Stanza("message", { from: "syncchannel@example.com", xmlns: "jabber:client" })
				.tag("result", { xmlns: "urn:xmpp:mam:2", queryid: queryId, id: "mam1" })
					.tag("forwarded", { xmlns: "urn:xmpp:forward:0" })
						.tag("delay", { xmlns: "urn:xmpp:delay", stamp: "2023-01-01T00:00:00Z" }).up()
						.tag("message", { from: "syncchannel@example.com/user2", to: "test@example.com", xmlns: "jabber:client" })
							.textTag("body", "mam message 1")
						.up()
					.up()
				.up()
			);

			client.stream.onStanza(new Stanza("message", { from: "syncchannel@example.com", xmlns: "jabber:client" })
				.tag("result", { xmlns: "urn:xmpp:mam:2", queryid: queryId, id: "mam2" })
					.tag("forwarded", { xmlns: "urn:xmpp:forward:0" })
						.tag("delay", { xmlns: "urn:xmpp:delay", stamp: "2023-01-01T00:00:01Z" }).up()
						.tag("message", { from: "syncchannel@example.com/user2", to: "test@example.com", xmlns: "jabber:client" })
							.textTag("body", "mam message 2")
						.up()
					.up()
				.up()
			);

			// Live message arrives during sync
			client.stream.onStanza(new Stanza("message", { from: "syncchannel@example.com/user1", id: "live1", type: "groupchat", xmlns: "jabber:client" }).textTag("body", "live message"));

			client.stream.onStanza(new Stanza("message", { from: "syncchannel@example.com", xmlns: "jabber:client" })
				.tag("result", { xmlns: "urn:xmpp:mam:2", queryid: queryId, id: "mam3" })
					.tag("forwarded", { xmlns: "urn:xmpp:forward:0" })
						.tag("delay", { xmlns: "urn:xmpp:delay", stamp: "2023-01-01T00:00:02Z" }).up()
						.tag("message", { from: "syncchannel@example.com/user2", to: "test@example.com", xmlns: "jabber:client", "id": "lmam3" })
							.textTag("body", "mam message 3")
						.up()
					.up()
				.up()
			);

			client.stream.onStanza(new Stanza("iq", { type: "result", id: iqId, from: "test@example.com", xmlns: "jabber:client" })
				.tag("fin", { xmlns: "urn:xmpp:mam:2", "complete": "true" })
					.tag("set", { xmlns: "http://jabber.org/protocol/rsm" })
						.textTag("last", "mam3")
					.up()
				.up()
			);
		});
	}
}
