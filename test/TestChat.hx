package test;

import utest.Assert;
import utest.Async;
import borogove.Client;
import borogove.ChatMessageBuilder;
import borogove.Stanza;
import borogove.JID;
import borogove.persistence.Dummy;

@:access(borogove)
class TestChat extends utest.Test {
	public function testGetMessagesBeforeNull(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = client.getDirectChat("friend@example.com");

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			final query = stanza.findChild("{urn:xmpp:mam:2}query");
			if (stanza.name == "iq" && query != null) {
				final rsm = stanza.findChild("{urn:xmpp:mam:2}query/{http://jabber.org/protocol/rsm}set");
				Assert.notNull(rsm, "RSM set should be present");
				final before = rsm.getChild("before");
				Assert.notNull(before, "before element should be present");
				Assert.equals("", before.getText());
				async.done();
				return EventHandled;
			}
			return EventUnhandled;
		});

		chat.getMessagesBefore(null);
	}

	public function testGetMessagesBefore(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = client.getDirectChat("friend@example.com");
		final builder = new ChatMessageBuilder();
		builder.serverId = "msg123";
		builder.direction = MessageSent;
		builder.recipients = [JID.parse("friend@example.com")];
		builder.to = JID.parse("friend@example.com");
		builder.from = JID.parse("test@example.com");
		builder.senderId = "test@example.com";
		final message = builder.build();

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			final query = stanza.findChild("{urn:xmpp:mam:2}query");
			if (stanza.name == "iq" && query != null) {
				final rsm = stanza.findChild("{urn:xmpp:mam:2}query/{http://jabber.org/protocol/rsm}set");
				Assert.notNull(rsm, "RSM set should be present");
				final before = rsm.getChild("before");
				Assert.notNull(before, "before element should be present");
				Assert.equals("msg123", before.getText());
				async.done();
				return EventHandled;
			}
			return EventUnhandled;
		});

		chat.getMessagesBefore(message);
	}

	public function testGetMessagesAfterNull(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = client.getDirectChat("friend@example.com");

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			final query = stanza.findChild("{urn:xmpp:mam:2}query");
			if (stanza.name == "iq" && query != null) {
				final rsm = stanza.findChild("{urn:xmpp:mam:2}query/{http://jabber.org/protocol/rsm}set");
				Assert.isNull(rsm, "RSM set should NOT be present");
				async.done();
				return EventHandled;
			}
			return EventUnhandled;
		});

		chat.getMessagesAfter(null);
	}

	public function testGetMessagesAfter(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = client.getDirectChat("friend@example.com");
		final builder = new ChatMessageBuilder();
		builder.serverId = "msg456";
		builder.direction = MessageSent;
		builder.recipients = [JID.parse("friend@example.com")];
		builder.to = JID.parse("friend@example.com");
		builder.from = JID.parse("test@example.com");
		builder.senderId = "test@example.com";
		final message = builder.build();

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			final query = stanza.findChild("{urn:xmpp:mam:2}query");
			if (stanza.name == "iq" && query != null) {
				final rsm = stanza.findChild("{urn:xmpp:mam:2}query/{http://jabber.org/protocol/rsm}set");
				Assert.notNull(rsm, "RSM set should be present");
				final after = rsm.getChild("after");
				Assert.notNull(after, "after element should be present");
				Assert.equals("msg456", after.getText());
				async.done();
				return EventHandled;
			}
			return EventUnhandled;
		});

		chat.getMessagesAfter(message);
	}

	public function testGetMessagesBeforeNullChannel(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new borogove.Chat.Channel(client, client.stream, persistence, "channel@example.com");

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			final query = stanza.findChild("{urn:xmpp:mam:2}query");
			if (stanza.name == "iq" && query != null) {
				final rsm = stanza.findChild("{urn:xmpp:mam:2}query/{http://jabber.org/protocol/rsm}set");
				Assert.notNull(rsm, "RSM set should be present");
				final before = rsm.getChild("before");
				Assert.notNull(before, "before element should be present");
				Assert.equals("", before.getText());
				async.done();
				return EventHandled;
			}
			return EventUnhandled;
		});

		chat.getMessagesBefore(null);
	}

	public function testGetMessagesBeforeChannel(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new borogove.Chat.Channel(client, client.stream, persistence, "channel@example.com");
		final builder = new ChatMessageBuilder();
		builder.serverId = "cmsg123";
		builder.direction = MessageSent;
		builder.recipients = [JID.parse("channel@example.com")];
		builder.to = JID.parse("channel@example.com");
		builder.from = JID.parse("test@example.com/res");
		builder.senderId = "test@example.com/res";
		final message = builder.build();

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			final query = stanza.findChild("{urn:xmpp:mam:2}query");
			if (stanza.name == "iq" && query != null) {
				final rsm = stanza.findChild("{urn:xmpp:mam:2}query/{http://jabber.org/protocol/rsm}set");
				Assert.notNull(rsm, "RSM set should be present");
				final before = rsm.getChild("before");
				Assert.notNull(before, "before element should be present");
				Assert.equals("cmsg123", before.getText());
				async.done();
				return EventHandled;
			}
			return EventUnhandled;
		});

		chat.getMessagesBefore(message);
	}

	public function testGetMessagesAfterNullChannel(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new borogove.Chat.Channel(client, client.stream, persistence, "channel@example.com");

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			final query = stanza.findChild("{urn:xmpp:mam:2}query");
			if (stanza.name == "iq" && query != null) {
				final rsm = stanza.findChild("{urn:xmpp:mam:2}query/{http://jabber.org/protocol/rsm}set");
				Assert.isNull(rsm, "RSM set should NOT be present");
				async.done();
				return EventHandled;
			}
			return EventUnhandled;
		});

		chat.getMessagesAfter(null);
	}

	public function testGetMessagesAfterChannel(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new borogove.Chat.Channel(client, client.stream, persistence, "channel@example.com");
		final builder = new ChatMessageBuilder();
		builder.serverId = "cmsg456";
		builder.direction = MessageSent;
		builder.recipients = [JID.parse("channel@example.com")];
		builder.to = JID.parse("channel@example.com");
		builder.from = JID.parse("test@example.com/res");
		builder.senderId = "test@example.com/res";
		final message = builder.build();

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			final query = stanza.findChild("{urn:xmpp:mam:2}query");
			if (stanza.name == "iq" && query != null) {
				final rsm = stanza.findChild("{urn:xmpp:mam:2}query/{http://jabber.org/protocol/rsm}set");
				Assert.notNull(rsm, "RSM set should be present");
				final after = rsm.getChild("after");
				Assert.notNull(after, "after element should be present");
				Assert.equals("cmsg456", after.getText());
				async.done();
				return EventHandled;
			}
			return EventUnhandled;
		});

		chat.getMessagesAfter(message);
	}

	public function testModerate(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new borogove.Chat.Channel(client, client.stream, persistence, "channel@example.com");
		final builder = new ChatMessageBuilder();
		builder.serverId = "msg123";
		builder.serverIdBy = "channel@example.com";
		builder.to = JID.parse("test@example.com");
		builder.from = JID.parse("channel@example.com/spammer");
		builder.senderId = "friend@example.com";
		final message = builder.build();

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "iq" && stanza.attr.get("type") == "set") {
				Assert.notNull(stanza.attr.get("id"));
				Assert.equals("channel@example.com", stanza.attr.get("to"));
				final moderate = stanza.getChild("moderate", "urn:xmpp:message-moderate:1");
				if (moderate != null) {
					Assert.equals("msg123", moderate.attr.get("id"));
					Assert.notNull(moderate.getChild("retract", "urn:xmpp:message-retract:1"));
					Assert.equals("Spam", moderate.getChild("reason").getText());
					async.done();
					return EventHandled;
				}
			}
			return EventUnhandled;
		});

		chat.moderate(message, "Spam");
	}

	public function testCanModerateDirectChat() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = client.getDirectChat("friend@example.com");
		Assert.isFalse(chat.canModerate());
	}

	public function testCanModerateChannel() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new borogove.Chat.Channel(client, client.stream, persistence, "channel@example.com");

		// Default
		Assert.isFalse(chat.canModerate());

		// Feature present but not moderator
		chat.disco = new borogove.Caps("", [], ["urn:xmpp:message-moderate:1", "http://jabber.org/protocol/muc"], []);
		Assert.isFalse(chat.canModerate());

		// Nick in use set
		chat._nickInUse = "mynick";
		Assert.isFalse(chat.canModerate());

		// Presence set but not moderator
		final p = new borogove.Presence(null, new Stanza("x", { xmlns: "http://jabber.org/protocol/muc#user" }).tag("item", { role: "participant" }).up(), null);
		chat.presence.set("mynick", p);
		Assert.isFalse(chat.canModerate());

		// Is moderator
		final p2 = new borogove.Presence(null, new Stanza("x", { xmlns: "http://jabber.org/protocol/muc#user" }).tag("item", { role: "moderator" }).up(), null);
		chat.presence.set("mynick", p2);
		Assert.isTrue(chat.canModerate());
	}
}
