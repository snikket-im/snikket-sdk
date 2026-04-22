package test;

import utest.Assert;
import utest.Async;
import borogove.Client;
import borogove.ChatMessageBuilder;
import borogove.Stanza;
import borogove.JID;
import borogove.persistence.Dummy;
import borogove.Chat.Channel;
import borogove.Chat.AvailableChat;
import borogove.Caps.Identity;

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

	public function testJoinFailure() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final caps = new borogove.Caps("", [new Identity("conference", "text", "Channel")], ["http://jabber.org/protocol/muc"], []);
		final availableChat = new AvailableChat("channel@example.com", "Channel", "", caps);
		final channel = cast(client.startChat(availableChat), Channel);

		Assert.isTrue(channel.syncing(), "Should be syncing initially");

		final errorStanza = new Stanza("presence", { xmlns: "jabber:client", from: "channel@example.com/test", to: "test@example.com", type: "error" })
			.tag("error", { type: "auth" })
				.tag("forbidden", { xmlns: "urn:ietf:params:xml:ns:xmpp-stanzas" }).up()
			.up();

		client.stream.onStanza(errorStanza);

		Assert.equals(channel.joinFailed, errorStanza, "joinFailed should be set");
		Assert.isFalse(channel.syncing(), "Should NOT be syncing after join failure");
	}

	public function testSyncFailure(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final caps = new borogove.Caps("", [new Identity("conference", "text", "Channel")], ["http://jabber.org/protocol/muc", "urn:xmpp:mam:2"], []);
		final availableChat = new AvailableChat("channel@example.com", "Channel", "", caps);
		final channel = cast(client.startChat(availableChat), Channel);

		Assert.isTrue(channel.syncing(), "Should be syncing initially");

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "iq") {
				// Delay of 0 to force async like in real life
				haxe.Timer.delay(() -> {
					final errorStanza = new Stanza("iq", { xmlns: "jabber:client", type: "error", id: stanza.attr.get("id") })
						.tag("error", { type: "cancel" })
							.tag("feature-not-implemented", { xmlns: "urn:ietf:params:xml:ns:xmpp-stanzas" }).up()
						.up();

					client.stream.onStanza(errorStanza);

					Assert.isNull(channel.sync, "sync should be cleared after failure");
					Assert.isFalse(channel.inSync, "Should not be inSync");
					Assert.isFalse(channel.syncing(), "Should NOT be syncing after sync failure");
					async.done();
				}, 0);
			}

			return EventHandled;
		});

		channel.doSync(null);
		Assert.notNull(channel.sync, "sync should be set during sync");
		Assert.isTrue(channel.syncing(), "Should be syncing during sync");
	}

	public function testSyncPointWhenNotInSync() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final channel = new Channel(client, client.stream, persistence, "channel@example.com");

		channel.inSync = false;
		final builder = new ChatMessageBuilder();
		final stanza = new Stanza("message", { from: "channel@example.com/someone" });
		channel.prepareIncomingMessage(builder, stanza);

		Assert.isFalse(builder.syncPoint, "Message should NOT have syncPoint if NOT inSync");

		channel.inSync = true;
		channel.prepareIncomingMessage(builder, stanza);
		Assert.isTrue(builder.syncPoint, "Message SHOULD have syncPoint if inSync");
	}

	public function testGetParticipantDetailsWithRoles() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new Channel(client, client.stream, persistence, "channel@example.com");

		final stanza = Stanza.parse('<presence from="channel@example.com/other">
			<x xmlns="http://jabber.org/protocol/muc#user"><item affiliation="admin" role="participant"/></x>
			<hats xmlns="urn:xmpp:hats:0">
				<hat uri="http://example.com/custom" title="Custom Role"/>
			</hats>
		</presence>');
		chat.presence.set("other", stanza);

		final details = chat.getParticipantDetails("channel@example.com/other");
		Assert.equals(2, details.roles.length);
		Assert.equals("admin", details.roles[0].id);
		Assert.equals("Admin", details.roles[0].title);
		Assert.equals("http://example.com/custom", details.roles[1].id);
		Assert.equals("Custom Role", details.roles[1].title);
	}

	public function testAvailableRoles() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new Channel(client, client.stream, persistence, "channel@example.com");
		chat._nickInUse = "me";

		// I am owner
		final myPresence = Stanza.parse('<presence from="channel@example.com/me">
			<x xmlns="http://jabber.org/protocol/muc#user"><item affiliation="owner" role="moderator"/></x>
		</presence>');
		chat.presence.set("me", myPresence);

		// Other is member
		final otherPresence = Stanza.parse('<presence from="channel@example.com/other">
			<x xmlns="http://jabber.org/protocol/muc#user"><item affiliation="member" role="participant" jid="other@example.com"/></x>
		</presence>');
		chat.presence.set("other", otherPresence);

		final roles = chat.availableRoles("channel@example.com/other");
		final ids = roles.map(r -> r.id);
		Assert.contains("owner", ids);
		Assert.contains("admin", ids);
		Assert.contains("outcast", ids);
		Assert.isFalse(ids.contains("member"), "Should not include current role");
	}

	public function testAddRole(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new Channel(client, client.stream, persistence, "channel@example.com");

		final otherPresence = Stanza.parse('<presence from="channel@example.com/other">
			<x xmlns="http://jabber.org/protocol/muc#user"><item affiliation="member" role="participant" jid="other@example.com"/></x>
		</presence>');
		chat.presence.set("other", otherPresence);

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "iq" && stanza.attr.get("type") == "set") {
				final query = stanza.getChild("query", "http://jabber.org/protocol/muc#admin");
				if (query != null) {
					final item = query.getChild("item");
					Assert.equals("admin", item.attr.get("affiliation"));
					Assert.equals("other@example.com", item.attr.get("jid"));
					async.done();
					return EventHandled;
				}
			}
			return EventUnhandled;
		});

		chat.addRole("channel@example.com/other", borogove.Role.forAffiliation("admin"));
	}

	public function testRemoveRole(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new Channel(client, client.stream, persistence, "channel@example.com");

		final otherPresence = Stanza.parse('<presence from="channel@example.com/other">
			<x xmlns="http://jabber.org/protocol/muc#user"><item affiliation="member" role="participant" jid="other@example.com"/></x>
		</presence>');
		chat.presence.set("other", otherPresence);

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "iq" && stanza.attr.get("type") == "set") {
				final query = stanza.getChild("query", "http://jabber.org/protocol/muc#admin");
				if (query != null) {
					final item = query.getChild("item");
					Assert.equals("none", item.attr.get("affiliation"));
					Assert.equals("other@example.com", item.attr.get("jid"));
					async.done();
					return EventHandled;
				}
			}
			return EventUnhandled;
		});

		chat.removeRole("channel@example.com/other", borogove.Role.forAffiliation("member"));
	}
}
