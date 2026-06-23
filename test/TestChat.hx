package test;

import utest.Assert;
import utest.Async;
import borogove.Client;
import borogove.ChatMessageBuilder;
import borogove.Stanza;
import borogove.JID;
import borogove.persistence.Dummy;
import borogove.CapsRepo;
import borogove.Chat.Channel;
import borogove.Chat.AvailableChat;
import borogove.Caps.Identity;
import borogove.Member;
import borogove.Role;
import thenshim.Promise;

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

	public function testChannelCommandsReturnsSettingsForOwner(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new borogove.Chat.Channel(client, client.stream, persistence, "channel@example.com");

		chat.self = new Member("me", "myself", null, true, [new Role("member", "")], JID.parse("test@example.com"), new Map(), null);
		chat.commands().then(cmds -> {
			Assert.equals(0, cmds.length);

			chat.self = new Member("me", "myself", null, true, [new Role("owner", "")], JID.parse("test@example.com"), new Map(), null);
			chat.commands().then(cmds2 -> {
				Assert.equals(1, cmds2.length);
				Assert.equals("Settings", cmds2[0].name);
				async.done();
			});
		});
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

		chat.self = new Member("me", "myself", null, true, [], JID.parse("test@example.com"), new Map(), null);
		Assert.isFalse(chat.canModerate());

		// Presence set but not moderator
		chat.self = new Member(
			"me", "myself", null, true, [], JID.parse("test@example.com"),
			["myself" => new borogove.Presence(null, new Stanza("x", { xmlns: "http://jabber.org/protocol/muc#user" }).tag("item", { role: "participant" }).up(), null)],
			null
		);
		Assert.isFalse(chat.canModerate());

		// Is moderator
		chat.self = new Member(
			"me", "myself", null, true, [], JID.parse("test@example.com"),
			["myself" => new borogove.Presence(null, new Stanza("x", { xmlns: "http://jabber.org/protocol/muc#user" }).tag("item", { role: "moderator" }).up(), null)],
			null
		);
		Assert.isTrue(chat.canModerate());
	}

	public function testCanSetSubjectChannel() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new borogove.Chat.Channel(client, client.stream, persistence, "channel@example.com");

		// Default
		Assert.isFalse(chat.canSetSubject());

		// Self set but no disco
		chat.self = new Member(
			"me", "myself", null, true, [], JID.parse("test@example.com"),
			["myself" => new borogove.Presence(null, new Stanza("x", { xmlns: "http://jabber.org/protocol/muc#user" }).tag("item", { role: "participant" }).up(), null)],
			null
		);
		Assert.isFalse(chat.canSetSubject());

		chat.disco = new borogove.Caps("", [], [], []);

		// Is participant, subjectmod not set
		Assert.isFalse(chat.canSetSubject());

		// Is moderator, subjectmod not set
		chat.self = new Member(
			"me", "myself", null, true, [], JID.parse("test@example.com"),
			["myself" => new borogove.Presence(null, new Stanza("x", { xmlns: "http://jabber.org/protocol/muc#user" }).tag("item", { role: "moderator" }).up(), null)],
			null
		);
		Assert.isTrue(chat.canSetSubject());

		// Is participant, subjectmod set
		chat.self = new Member(
			"me", "myself", null, true, [], JID.parse("test@example.com"),
			["myself" => new borogove.Presence(null, new Stanza("x", { xmlns: "http://jabber.org/protocol/muc#user" }).tag("item", { role: "participant" }).up(), null)],
			null
		);
		chat.disco = new borogove.Caps("", [], [], [new Stanza("x", { xmlns: "jabber:x:data", type: "result" }).tag("field", { "var": "FORM_TYPE", type: "hidden" }).textTag("value", "http://jabber.org/protocol/muc#roominfo").up().tag("field", { "var": "muc#roominfo_subjectmod" }).textTag("value", "1").up()]);
		Assert.isTrue(chat.canSetSubject());
	}

	public function testSetSubject(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new borogove.Chat.Channel(client, client.stream, persistence, "channel@example.com");

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "message" && stanza.attr.get("to") == "channel@example.com") {
				Assert.equals("New Subject", stanza.getChild("subject").getText());
				Assert.equals("groupchat", stanza.attr.get("type"));
				async.done();
				return EventHandled;
			}
			return EventUnhandled;
		});

		chat.outbox.start();
		chat.setSubject("New Subject");
	}

	public function testSetSubjectThread(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new borogove.Chat.Channel(client, client.stream, persistence, "channel@example.com");

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "message" && stanza.attr.get("to") == "channel@example.com") {
				Assert.equals("New Thread Subject", stanza.getChild("subject").getText());
				Assert.equals("thread123", stanza.getChild("thread").getText());
				async.done();
				return EventHandled;
			}
			return EventUnhandled;
		});

		chat.outbox.start();
		chat.setSubject("New Thread Subject", "thread123");
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

	public function testJoinSuccess() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final caps = new borogove.Caps("", [new Identity("conference", "text", "Channel")], ["http://jabber.org/protocol/muc"], []);
		final availableChat = new AvailableChat("channel@example.com", "Channel", "", caps);
		final channel = cast(client.startChat(availableChat), Channel);

		Assert.isNull(channel.self);

		final joinedStanza = new Stanza("presence", { xmlns: "jabber:client", from: "channel@example.com/test", to: "test@example.com" })
			.tag("x", { xmlns: "http://jabber.org/protocol/muc#user" }).tag("status", { code: "110" }).up()
			.up();

		client.stream.onStanza(joinedStanza);

		Assert.notNull(channel.self);
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

	public function testAvailableRoles() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new Channel(client, client.stream, persistence, "channel@example.com");
		chat.self = new Member("me", "myself", null, true, [new Role("owner", "")], JID.parse("test@example.com"), new Map(), null);

		final roles = chat.availableRoles(new Member("other", "other", null, true, [], JID.parse("test@example.com"), new Map(), null));
		final ids = roles.map(r -> r.id);
		Assert.contains("owner", ids);
		Assert.contains("admin", ids);
		Assert.contains("outcast", ids);
		Assert.contains("none", ids);
	}

	public function testAvailableRolesForNone() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new Channel(client, client.stream, persistence, "channel@example.com");
		chat.self = new Member("me", "myself", null, true, [new Role("owner", "")], JID.parse("test@example.com"), new Map(), null);

		final roles = chat.availableRoles(new Member("other", "other", null, true, [new Role("none", "")], JID.parse("test@example.com"), new Map(), null));
		final ids = roles.map(r -> r.id);
		Assert.contains("owner", ids);
		Assert.contains("admin", ids);
		Assert.contains("outcast", ids);
		Assert.isFalse(ids.contains("none"));
	}

	public function testAddRole(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new Channel(client, client.stream, persistence, "channel@example.com");

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

		chat.addRole(new Member("other", "other", null, true, [], JID.parse("test@example.com"), new Map(), new AvailableChat("other@example.com", "", "", CapsRepo.empty)), borogove.Role.forAffiliation("admin"));
	}

	public function testRemoveRole(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new Channel(client, client.stream, persistence, "channel@example.com");

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "iq" && stanza.attr.get("type") == "set") {
				final query = stanza.getChild("query", "http://jabber.org/protocol/muc#admin");
				if (query != null) {
					final item = query.getChild("item");
					Assert.equals("member", item.attr.get("affiliation"));
					Assert.equals("other@example.com", item.attr.get("jid"));
					async.done();
					return EventHandled;
				}
			}
			return EventUnhandled;
		});

		chat.removeRole(new Member("other", "other", null, true, [new Role("admin", "")], JID.parse("test@example.com"), new Map(), new AvailableChat("other@example.com", "", "", CapsRepo.empty)), borogove.Role.forAffiliation("admin"));
	}

	public function testDirectChatMembers(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new borogove.Chat.DirectChat(client, client.stream, persistence, "alice@example.com\nbob@example.com");

		chat.members().then(members -> {
			Assert.equals(3, members.length);
			Assert.equals("alice@example.com", members[0].id);
			Assert.equals("bob@example.com", members[1].id);
			Assert.equals("test@example.com", members[2].id);
			Assert.isTrue(members[2].isSelf);
			Assert.equals("alice@example.com (via alice@example.com\nbob@example.com)", members[0].chat.note);
			async.done();
		});
	}

	public function testDirectChatMultiDisplayName() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		client.getDirectChat("bob@example.com").displayName = "Bobby";
		client.getDirectChat("alice@example.com").displayName = "Alice";
		final chat = new borogove.Chat.DirectChat(client, client.stream, persistence, "bob@example.com\nalice@example.com");

		Assert.equals("Alice, Bobby", chat.getDisplayName());
	}

	public function testChannelMembersPassesModeratorFlag(async: Async) {
		final persistence = new ChannelMembersPersistence();
		final client = new Client("test@example.com", persistence);
		final chat = new Channel(client, client.stream, persistence, "channel@example.com");
		chat.self = new Member("me", "myself", null, true, [new Role("admin", "Admin")], JID.parse("test@example.com"), new Map(), null);

		chat.members().then(members -> {
			Assert.isTrue(persistence.forModerator);
			Assert.equals(1, members.length);
			Assert.equals("other", members[0].id);
			async.done();
		});
	}

	public function testCanAudioCallPSTN() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);

		final domain = "pstn.example.com";
		final domainChat = client.getDirectChat(domain);

		final caps = new borogove.Caps("", [new Identity("gateway", "pstn", "PSTN Gateway")], [], []);
		final presence = new borogove.Presence(caps, null, null);
		domainChat.presence.set("", presence);
		client.capsRepo.add(caps);

		final chat = client.getDirectChat("+123456789@" + domain);
		Assert.isTrue(chat.canAudioCall());
	}

	public function testCanSetPhoto() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new borogove.Chat.Channel(client, client.stream, persistence, "channel@example.com");

		Assert.isFalse(chat.canSetPhoto());

		chat.self = new Member("me", "myself", null, true, [new Role("member", "")], JID.parse("test@example.com"), new Map(), null);
		Assert.isFalse(chat.canSetPhoto());

		chat.self = new Member("me", "myself", null, true, [new Role("owner", "")], JID.parse("test@example.com"), new Map(), null);
		Assert.isTrue(chat.canSetPhoto());
	}

	public function testSetPhoto(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new borogove.Chat.Channel(client, client.stream, persistence, "channel@example.com");

		#if js
		final source = new js.html.File([], "", { type: "image/png" });
		#else
		final source = Type.createEmptyInstance(borogove.AttachmentSource);
		Reflect.setField(source, "path", "/dev/null");
		Reflect.setField(source, "size", 100);
		Reflect.setField(source, "type", "image/png");
		#end

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "iq" && stanza.attr.get("type") == "set") {
				final vcard = stanza.getChild("vCard", "vcard-temp");
				if (vcard != null) {
					final photo = vcard.getChild("PHOTO");
					Assert.notNull(photo);
					Assert.equals("image/png", photo.getChild("TYPE").getText());
					Assert.equals("", photo.getChild("BINVAL").getText());
					async.done();
					return EventHandled;
				}
			}
			return EventUnhandled;
		});

		chat.setPhoto(source);
	}

	public function testSetPhotoTooBig() {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new borogove.Chat.Channel(client, client.stream, persistence, "channel@example.com");

		#if js
		var s = "";
		for (i in 1...200000) {
			s = s += "a";
		}
		final source = new js.html.File([s], "", { type: "image/png" });
		#else
		final source = Type.createEmptyInstance(borogove.AttachmentSource);
		Reflect.setField(source, "path", "/dev/null");
		Reflect.setField(source, "size", 200000);
		Reflect.setField(source, "type", "image/png");
		#end

		Assert.raises(() -> chat.setPhoto(source), String);
	}

	public function testRequestToSend(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new borogove.Chat.Channel(client, client.stream, persistence, "channel@example.com");

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "message" && stanza.attr.get("to") == "channel@example.com" && stanza.attr.get("type") == null) {
				final x = stanza.getChild("x", "jabber:x:data");
				if (x != null && x.attr.get("type") == "submit") {
					final fields = x.allTags("field");
					Assert.equals(2, fields.length);
					Assert.equals("FORM_TYPE", fields[0].attr.get("var"));
					Assert.equals("http://jabber.org/protocol/muc#request", fields[0].getChild("value").getText());
					Assert.equals("muc#role", fields[1].attr.get("var"));
					Assert.equals("participant", fields[1].getChild("value").getText());
					async.done();
					return EventHandled;
				}
			}
			return EventUnhandled;
		});

		chat.outbox.start();
		chat.requestToSend();
	}

	public function testVoiceRequestRespond(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final chat = new borogove.Chat.Channel(client, client.stream, persistence, "channel@example.com");
		final member = new Member("some_id", "some_name", null, false, [], JID.parse("someone@example.com"), new Map(), new AvailableChat("someone_chat@example.com", "", "", CapsRepo.empty));

		var count = 0;
		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "message" && stanza.attr.get("to") == "channel@example.com" && stanza.attr.get("type") == null) {
				final x = stanza.getChild("x", "jabber:x:data");
				if (x != null && x.attr.get("type") == "submit") {
					final fields = x.allTags("field");
					Assert.equals(4, fields.length);
					Assert.equals("FORM_TYPE", fields[0].attr.get("var"));
					Assert.equals("http://jabber.org/protocol/muc#request", fields[0].getChild("value").getText());
					Assert.equals("muc#role", fields[1].attr.get("var"));
					Assert.equals("participant", fields[1].getChild("value").getText());
					Assert.equals("muc#jid", fields[2].attr.get("var"));
					Assert.equals("someone_chat@example.com", fields[2].getChild("value").getText());
					Assert.equals("muc#request_allow", fields[3].attr.get("var"));

					if (count == 0) {
						Assert.equals("1", fields[3].getChild("value").getText());
					} else {
						Assert.equals("0", fields[3].getChild("value").getText());
						async.done();
					}
					count++;
					return EventHandled;
				}
			}
			return EventUnhandled;
		});

		chat.outbox.start();
		chat.voiceRequestRespond(member, true);
		chat.voiceRequestRespond(member, false);
	}
}

@:access(borogove)
class ChannelMembersPersistence extends Dummy {
	public var forModerator = false;

	override public function getMembers(accountId: String, chat: borogove.Chat, forModerator: Bool) {
		this.forModerator = forModerator;
		return Promise.resolve([
			new Member(chat.chatId, "Room", null, false, [], JID.parse(chat.chatId), new Map(), null),
			new Member("other", "Other", null, false, [], JID.parse("other@example.com"), new Map(), new AvailableChat("other@example.com", "", "", CapsRepo.empty))
		]);
	}
}
