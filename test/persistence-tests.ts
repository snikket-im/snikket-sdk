import { expect } from "vitest";

export function sharedPersistenceTests(test) {
	test("storeChats and getChats", async ({ borogove, persistence }) => {
		const chat = new borogove.DirectChat(
			null,
			null,
			persistence,
			"hatter@example.com",
		);
		chat.displayName = "The Mad Hatter";
		chat.trusted = true;
		chat.threads = new Map([
			[null, "Tea Time"],
			["thread-1", "Introductions"],
		]);

		await persistence.storeChats("alice@example.com", [chat]);
		const chats = await persistence.getChats("alice@example.com");
		expect(chats.length).toBe(1);
		expect(chats[0]?.chatId).toBe("hatter@example.com");
		expect(chats[0]?.displayName).toBe("The Mad Hatter");
		expect(chats[0]?.trusted).toBe(true);
		expect(chats[0]?.klass).toBe("DirectChat");
		expect(chats[0]?.threads?.get(null)).toBe("Tea Time");
		expect(chats[0]?.threads?.get("thread-1")).toBe("Introductions");
	});

	test("storeChats and getChats with status", async ({
		borogove,
		persistence,
	}) => {
		const chat = new borogove.DirectChat(
			null,
			null,
			persistence,
			"hatter@example.com",
		);
		chat.displayName = "The Mad Hatter";
		chat.trusted = true;
		chat.status = new borogove.Status("🎩", "Time for tea!");

		await persistence.storeChats("alice@example.com", [chat]);
		const chats = await persistence.getChats("alice@example.com");
		expect(chats.length).toBe(1);
		expect(chats[0]?.chatId).toBe("hatter@example.com");
		expect(chats[0]?.status?.emoji).toBe("🎩");
		expect(chats[0]?.status?.text).toBe("Time for tea!");
	});

	test("getChats uses member presence for direct chats", async ({
		borogove,
		persistence,
	}) => {
		const chat = new borogove.DirectChat(
			null,
			null,
			persistence,
			"hatter@example.com",
		);
		chat.displayName = "The Mad Hatter";
		chat.trusted = true;

		await persistence.storeChats("alice@example.com", [chat]);
		await persistence.storeMembers("alice@example.com", chat.chatId, [
			{
				id: "hatter@example.com",
				displayName: "The Mad Hatter",
				photoUri: null,
				isSelf: false,
				roles: [],
				jid: borogove.JID.parse("hatter@example.com"),
				presence: new Map([["phone", borogove.Stanza.parse("<presence />")]]),
				chat: null,
			},
		]);
		const [stored] = await persistence.getChats("alice@example.com");
		expect([...stored.presence.keys()]).toEqual(["phone"]);
	});

	test("getChats hydrates membersForName and mavUntil from members", async ({
		borogove,
		persistence,
		createChannel,
	}) => {
		const chat = createChannel(persistence, "room-chat-hydrate@example.com");
		chat.displayName = "Tea Room";
		chat.trusted = true;
		chat.mavUntil = "2024-05-01T12:00:00Z";

		await persistence.storeChats("alice@example.com", [chat]);
		await persistence.storeMembers("alice@example.com", chat.chatId, [
			{
				id: chat.chatId,
				displayName: "Tea Room",
				photoUri: null,
				isSelf: false,
				roles: [],
				jid: borogove.JID.parse(chat.chatId),
				presence: new Map(),
				chat: null,
			},
			{
				id: `${chat.chatId}/self`,
				displayName: "Myself",
				photoUri: null,
				isSelf: true,
				roles: [{ id: "owner", title: "Owner" }],
				jid: borogove.JID.parse("alice@example.com"),
				presence: new Map([["desk", borogove.Stanza.parse("<presence />")]]),
				chat: null,
			},
			{
				id: `${chat.chatId}/zulu`,
				displayName: "Zulu",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "admin", title: "Admin" }],
				jid: borogove.JID.parse("zulu@example.com"),
				presence: new Map([["desk", borogove.Stanza.parse("<presence />")]]),
				chat: { chatId: "zulu@example.com" },
			},
			{
				id: `${chat.chatId}/alpha`,
				displayName: "Alpha",
				photoUri: null,
				isSelf: false,
				roles: [],
				jid: borogove.JID.parse("alpha@example.com"),
				presence: new Map([["desk", borogove.Stanza.parse("<presence />")]]),
				chat: { chatId: "alpha@example.com" },
			},
			{
				id: `${chat.chatId}/hidden`,
				displayName: "Hidden",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "none", title: "Guest" }],
				jid: borogove.JID.parse("hidden@example.com"),
				presence: new Map([["desk", borogove.Stanza.parse("<presence />")]]),
				chat: { chatId: "hidden@example.com" },
			},
		]);
		const [stored] = await persistence.getChats("alice@example.com");
		expect(stored.mavUntil).toBe("2024-05-01T12:00:00Z");
		expect(stored.membersForName.map((m) => m.displayName)).toEqual([
			"Alpha",
			"Zulu",
		]);
		expect([...stored.presence.keys()]).toEqual(["desk"]);
	});

	test("hydrate replyToMessage for groupchats", async ({
		borogove,
		persistence,
	}) => {
		const builder = new borogove.ChatMessageBuilder({
			serverId: "parent",
			serverIdBy: "hatter@example.com",
			localId: "loc1",
			senderId: "hatter@example.com",
			direction: 0,
		});
		builder.sortId = "a0";
		builder.to = borogove.JID.parse("alice@example.com");
		builder.from = borogove.JID.parse("hatter@example.com");
		builder.recipients = [builder.to];
		builder.replyTo = [builder.from];
		builder.type = borogove.MessageType.MessageChannel;
		const parentStub = builder.build();

		builder.setBody(borogove.Html.text("Hello"));
		const parentMsg = builder.build();

		const builder2 = new borogove.ChatMessageBuilder({
			serverId: "child",
			serverIdBy: "hatter@example.com",
			localId: "loc2",
			senderId: "hatter@example.com",
			direction: 0,
		});
		builder2.sortId = "a1";
		builder2.to = borogove.JID.parse("alice@example.com");
		builder2.from = borogove.JID.parse("hatter@example.com");
		builder2.recipients = [builder2.to];
		builder2.replyTo = [builder2.from];
		builder2.replyToMessage = parentStub;
		builder2.type = borogove.MessageType.MessageChannel;

		await persistence.storeMessages("alice@example.com", [parentMsg]);
		const [childStored] = await persistence.storeMessages("alice@example.com", [
			builder2.build(),
		]);
		expect(childStored.replyToMessage.body().toPlainText()).toBe("Hello");
	});

	test("getMessage by serverId and localId", async ({
		borogove,
		persistence,
	}) => {
		const builder = new borogove.ChatMessageBuilder({
			serverId: "srv1",
			serverIdBy: "hatter@example.com",
			localId: "loc1",
			senderId: "hatter@example.com",
			direction: 0,
		});
		builder.sortId = "a0";
		builder.to = borogove.JID.parse("alice@example.com");
		builder.from = borogove.JID.parse("hatter@example.com");
		builder.recipients = [builder.to];
		builder.replyTo = [builder.from];
		const msg = builder.build();

		await persistence.storeMessages("alice@example.com", [msg]);

		const byServerId = await persistence.getMessage(
			"alice@example.com",
			"hatter@example.com",
			"srv1",
			null,
		);
		const byLocalId = await persistence.getMessage(
			"alice@example.com",
			"hatter@example.com",
			null,
			"loc1",
		);
		expect(byServerId).not.toBeNull();
		expect(byServerId.serverId).toBe("srv1");
		expect(byLocalId).not.toBeNull();
		expect(byLocalId.localId).toBe("loc1");
	});

	test("persists message encryption information", async ({
		borogove,
		persistence,
	}) => {
		const account = "encryption-alice@example.com";
		const chatId = "encryption-hatter@example.com";
		const builder = new borogove.ChatMessageBuilder({
			serverId: "encrypted-message",
			serverIdBy: account,
			senderId: chatId,
			direction: 0,
		});
		builder.sortId = "encrypted-a0";
		builder.syncPoint = true;
		builder.text = "Encrypted persistence marker";
		builder.to = borogove.JID.parse(account);
		builder.from = borogove.JID.parse(chatId);
		builder.recipients = [builder.to];
		builder.replyTo = [builder.from];
		builder.encryption = {
			status: borogove.EncryptionStatus.DecryptionFailure,
			method: "urn:xmpp:omemo:2",
			methodName: "OMEMO 2",
			reason: "invalid-key",
			reasonText: "The sender key was invalid",
		};

		const [stored] = await persistence.storeMessages(account, [
			builder.build(),
		]);
		const fetched = await persistence.getMessage(
			account,
			chatId,
			"encrypted-message",
			null,
		);
		const [searched] = await persistence.searchMessages(
			account,
			chatId,
			"persistence marker",
		);
		const [paged] = await persistence.getMessagesBefore(account, chatId);
		const syncPoint = await persistence.syncPoint(account, null);

		const fields = (message) => ({
			status: message?.encryption?.status,
			method: message?.encryption?.method,
			methodName: message?.encryption?.methodName,
			reason: message?.encryption?.reason,
			reasonText: message?.encryption?.reasonText,
		});
		const expected = {
			status: 1,
			method: "urn:xmpp:omemo:2",
			methodName: "OMEMO 2",
			reason: "invalid-key",
			reasonText: "The sender key was invalid",
		};
		expect(fields(stored)).toEqual(expected);
		expect(fields(fetched)).toEqual(expected);
		expect(fields(searched)).toEqual(expected);
		expect(fields(paged)).toEqual(expected);
		expect(fields(syncPoint)).toEqual(expected);
	});

	test("preserves encryption information when updating message status", async ({
		borogove,
		persistence,
	}) => {
		const account = "encryption-status-alice@example.com";
		const builder = new borogove.ChatMessageBuilder({
			localId: "encrypted-outgoing",
			senderId: account,
			direction: 1,
		});
		builder.sortId = "encrypted-b0";
		builder.to = borogove.JID.parse("encryption-hatter@example.com");
		builder.from = borogove.JID.parse(account);
		builder.recipients = [builder.to];
		builder.replyTo = [builder.from];
		builder.encryption = {
			status: borogove.EncryptionStatus.DecryptionSuccess,
			method: "eu.siacs.conversations.axolotl",
			methodName: "OMEMO",
			reason: null,
			reasonText: null,
		};

		await persistence.storeMessages(account, [builder.build()]);
		const updated = await persistence.updateMessageStatus(
			account,
			"encrypted-outgoing",
			1,
			"Delivered",
		);
		expect({
			status: updated.encryption?.status,
			method: updated.encryption?.method,
			methodName: updated.encryption?.methodName,
			reason: updated.encryption?.reason,
			reasonText: updated.encryption?.reasonText,
		}).toEqual({
			status: 0,
			method: "eu.siacs.conversations.axolotl",
			methodName: "OMEMO",
			reason: null,
			reasonText: null,
		});
	});

	test("preserves encryption information for corrected message versions", async ({
		borogove,
		persistence,
	}) => {
		const account = "encryption-correction-alice@example.com";
		const chatId = "encryption-correction-hatter@example.com";
		const originalBuilder = new borogove.ChatMessageBuilder({
			localId: "encrypted-original",
			senderId: account,
			direction: 1,
			timestamp: "2026-08-26T12:00:00Z",
		});
		originalBuilder.sortId = "encrypted-c0";
		originalBuilder.text = "Original encrypted text";
		originalBuilder.to = borogove.JID.parse(chatId);
		originalBuilder.from = borogove.JID.parse(account);
		originalBuilder.recipients = [originalBuilder.to];
		originalBuilder.replyTo = [originalBuilder.from];
		originalBuilder.encryption = {
			status: borogove.EncryptionStatus.DecryptionSuccess,
			method: "urn:xmpp:omemo:1",
			methodName: "OMEMO 1",
			reason: null,
			reasonText: null,
		};
		const original = originalBuilder.build();
		await persistence.storeMessages(account, [original]);

		const correctionBuilder = new borogove.ChatMessageBuilder({
			localId: "encrypted-correction",
			senderId: account,
			direction: 1,
			timestamp: "2026-08-26T12:01:00Z",
		});
		correctionBuilder.sortId = "encrypted-c0";
		correctionBuilder.text = "Corrected encrypted text";
		correctionBuilder.to = borogove.JID.parse(chatId);
		correctionBuilder.from = borogove.JID.parse(account);
		correctionBuilder.recipients = [correctionBuilder.to];
		correctionBuilder.replyTo = [correctionBuilder.from];
		correctionBuilder.encryption = {
			status: borogove.EncryptionStatus.DecryptionFailure,
			method: "urn:xmpp:omemo:2",
			methodName: "OMEMO 2",
			reason: "invalid-key",
			reasonText: "Correction could not be decrypted",
		};
		const correctionVersion = correctionBuilder.build();
		correctionBuilder.versions = [correctionVersion];
		correctionBuilder.localId = original.localId;

		const [stored] = await persistence.storeMessages(account, [
			correctionBuilder.build(),
		]);
		const [fetched] = await persistence.getMessagesBefore(account, chatId);
		const summarize = (message) => ({
			text: message.text,
			method: message.encryption?.method,
			reason: message.encryption?.reason,
			versions: message.versions.map((version) => ({
				text: version.text,
				method: version.encryption?.method,
				reason: version.encryption?.reason,
			})),
		});
		for (const message of [summarize(stored), summarize(fetched)]) {
			expect(message.text).toBe("Corrected encrypted text");
			expect(message.method).toBe("urn:xmpp:omemo:2");
			expect(message.reason).toBe("invalid-key");
			expect(message.versions).toEqual([
				{
					text: "Corrected encrypted text",
					method: "urn:xmpp:omemo:2",
					reason: "invalid-key",
				},
				{
					text: "Original encrypted text",
					method: "urn:xmpp:omemo:1",
					reason: null,
				},
			]);
		}
	});

	test("storeReaction", async ({ borogove, persistence }) => {
		const builder = new borogove.ChatMessageBuilder({
			serverId: "srv1",
			serverIdBy: "hatter@example.com",
			senderId: "hatter@example.com",
			direction: 0,
		});
		builder.sortId = "a0";
		builder.to = borogove.JID.parse("alice@example.com");
		builder.from = borogove.JID.parse("hatter@example.com");
		builder.recipients = [builder.to];
		builder.replyTo = [builder.from];
		await persistence.storeMessages("alice@example.com", [builder.build()]);

		const reaction = new borogove.Reaction(
			"alice@example.com",
			"2020-01-01T00:00:01Z",
			"👍",
		);
		const update = new borogove.ReactionUpdate(
			"up1",
			"srv1",
			"hatter@example.com",
			null,
			"hatter@example.com",
			"alice@example.com",
			"2020-01-01T00:00:01Z",
			[reaction],
			borogove.ReactionUpdateKind.EmojiReactions,
		);

		const msg = await persistence.storeReaction("alice@example.com", update);
		const reactions = [...msg.reactions.entries()].map(([k, v]) => ({
			key: k,
			count: v.length,
		}));
		expect(reactions.length).toBe(1);
		expect(reactions[0].key).toBe("👍");
		expect(reactions[0].count).toBe(1);
	});

	test("searchMessages", async ({ borogove, persistence }) => {
		const builder = new borogove.ChatMessageBuilder({
			serverId: "srv1",
			serverIdBy: "hatter@example.com",
			senderId: "hatter@example.com",
			direction: 0,
		});
		builder.sortId = "a0";
		builder.text = "Hello world";
		builder.to = borogove.JID.parse("alice@example.com");
		builder.from = borogove.JID.parse("hatter@example.com");
		builder.recipients = [builder.to];
		builder.replyTo = [builder.from];

		const builder2 = new borogove.ChatMessageBuilder({
			serverId: "srv2",
			serverIdBy: "hatter@example.com",
			senderId: "hatter@example.com",
			direction: 0,
		});
		builder2.sortId = "a1";
		builder2.text = "Goodbye world";
		builder2.to = borogove.JID.parse("alice@example.com");
		builder2.from = borogove.JID.parse("hatter@example.com");
		builder2.recipients = [builder2.to];
		builder2.replyTo = [builder2.from];

		await persistence.storeMessages("alice@example.com", [
			builder.build(),
			builder2.build(),
		]);

		const results = await persistence.searchMessages(
			"alice@example.com",
			"hatter@example.com",
			"hello",
		);
		expect(results.length).toBe(1);
		expect(results[0].text).toBe("Hello world");
	});

	test("1:1 come back ordered by sortId", async ({ borogove, persistence }) => {
		const builder = new borogove.ChatMessageBuilder({
			serverId: "1",
			serverIdBy: "alice@example.com",
			senderId: "hatter@example.com",
			direction: 0,
		});
		builder.sortId = "a0";
		builder.to = borogove.JID.parse("alice@example.com");
		builder.from = borogove.JID.parse("hatter@example.com");
		builder.replyTo = [builder.from];

		const builder2 = new borogove.ChatMessageBuilder({
			serverId: "2",
			serverIdBy: "alice@example.com",
			senderId: "hatter@example.com",
			direction: 0,
		});
		builder2.sortId = "b0";
		builder2.to = borogove.JID.parse("alice@example.com");
		builder2.from = borogove.JID.parse("hatter@example.com");
		builder2.replyTo = [builder.from];

		await persistence.storeMessages("alice@example.com", [
			builder2.build(),
			builder.build(),
		]);
		const messages = await persistence.getMessagesBefore(
			"alice@example.com",
			"hatter@example.com",
		);
		expect(messages.length).toBe(2);
		expect(messages[0].serverId).toBe("1");
		expect(messages[1].serverId).toBe("2");
	});

	test("getMessagesBefore the end: MUC come back ordered by sortId, PM by timestamp", async ({
		borogove,
		persistence,
	}) => {
		const builder = new borogove.ChatMessageBuilder({
			serverId: "1",
			serverIdBy: "teaparty@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannel,
			timestamp: "2020-01-01T00:00:01Z",
		});
		builder.sortId = "a0";
		builder.to = borogove.JID.parse("alice@example.com");
		builder.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder.replyTo = [builder.from.asBare()];

		const builder2 = new borogove.ChatMessageBuilder({
			serverId: "2",
			serverIdBy: "teaparty@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannel,
			timestamp: "2020-01-01T00:00:00Z",
		});
		builder2.sortId = "b0";
		builder2.to = borogove.JID.parse("alice@example.com");
		builder2.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder2.replyTo = [builder.from.asBare()];

		const builder3 = new borogove.ChatMessageBuilder({
			serverId: "3",
			serverIdBy: "alice@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannelPrivate,
			timestamp: "2020-01-01T00:00:03Z",
		});
		builder3.sortId = "a0";
		builder3.to = borogove.JID.parse("alice@example.com");
		builder3.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder3.replyTo = [builder.from.asBare()];

		await persistence.storeMessages("alice@example.com", [
			builder2.build(),
			builder3.build(),
			builder.build(),
		]);
		const messages = await persistence.getMessagesBefore(
			"alice@example.com",
			"teaparty@example.com",
		);
		expect(messages.length).toBe(3);
		expect(messages[0].serverId).toBe("1");
		expect(messages[1].serverId).toBe("2");
		expect(messages[2].serverId).toBe("3");
	});

	test("getMessagesBefore some point: MUC come back ordered by sortId, PM by timestamp", async ({
		borogove,
		persistence,
	}) => {
		const builder = new borogove.ChatMessageBuilder({
			serverId: "1",
			serverIdBy: "teaparty@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannel,
			timestamp: "2020-01-01T00:00:01Z",
		});
		builder.sortId = "a0";
		builder.to = borogove.JID.parse("alice@example.com");
		builder.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder.replyTo = [builder.from.asBare()];

		const builder2 = new borogove.ChatMessageBuilder({
			serverId: "2",
			serverIdBy: "teaparty@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannel,
			timestamp: "2020-01-01T00:00:00Z",
		});
		builder2.sortId = "b0";
		builder2.to = borogove.JID.parse("alice@example.com");
		builder2.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder2.replyTo = [builder.from.asBare()];

		const builder3 = new borogove.ChatMessageBuilder({
			serverId: "3",
			serverIdBy: "alice@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannelPrivate,
			timestamp: "2020-01-01T00:00:03Z",
		});
		builder3.sortId = "Z~";
		builder3.to = borogove.JID.parse("alice@example.com");
		builder3.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder3.replyTo = [builder.from.asBare()];

		const builder4 = new borogove.ChatMessageBuilder({
			serverId: "4",
			serverIdBy: "teaparty@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannel,
			timestamp: "2020-01-01T00:00:04Z",
		});
		builder4.sortId = "c0";
		builder4.to = borogove.JID.parse("alice@example.com");
		builder4.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder4.replyTo = [builder.from.asBare()];

		await persistence.storeMessages("alice@example.com", [
			builder2.build(),
			builder4.build(),
			builder3.build(),
			builder.build(),
		]);
		const messages = await persistence.getMessagesBefore(
			"alice@example.com",
			"teaparty@example.com",
			builder4.build(),
		);
		expect(messages.length).toBe(3);
		expect(messages[0].serverId).toBe("1");
		expect(messages[1].serverId).toBe("2");
		expect(messages[2].serverId).toBe("3");
	});

	test("getMessagesBefore a PM", async ({ borogove, persistence }) => {
		const builder = new borogove.ChatMessageBuilder({
			serverId: "1",
			serverIdBy: "teaparty@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannel,
			timestamp: "2020-01-01T00:00:00Z",
		});
		builder.sortId = "a0";
		builder.to = borogove.JID.parse("alice@example.com");
		builder.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder.replyTo = [builder.from.asBare()];

		const builder2 = new borogove.ChatMessageBuilder({
			serverId: "2",
			serverIdBy: "teaparty@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannel,
			timestamp: "2020-01-01T00:00:01Z",
		});
		builder2.sortId = "b0";
		builder2.to = borogove.JID.parse("alice@example.com");
		builder2.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder2.replyTo = [builder.from.asBare()];

		const builder3 = new borogove.ChatMessageBuilder({
			serverId: "3",
			serverIdBy: "alice@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannelPrivate,
			timestamp: "2020-01-01T00:00:03Z",
		});
		builder3.sortId = "Z~";
		builder3.to = borogove.JID.parse("alice@example.com");
		builder3.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder3.replyTo = [builder.from.asBare()];

		const builder4 = new borogove.ChatMessageBuilder({
			serverId: "4",
			serverIdBy: "teaparty@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannel,
			timestamp: "2020-01-01T00:00:04Z",
		});
		builder4.sortId = "c0";
		builder4.to = borogove.JID.parse("alice@example.com");
		builder4.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder4.replyTo = [builder.from.asBare()];

		await persistence.storeMessages("alice@example.com", [
			builder2.build(),
			builder4.build(),
			builder3.build(),
			builder.build(),
		]);
		const messages = await persistence.getMessagesBefore(
			"alice@example.com",
			"teaparty@example.com",
			builder3.build(),
		);
		expect(messages.length).toBe(2);
		expect(messages[0].serverId).toBe("1");
		expect(messages[1].serverId).toBe("2");
	});

	test("getMessagesAfter the start: MUC come back ordered by sortId, PM by timestamp", async ({
		borogove,
		persistence,
	}) => {
		const builder = new borogove.ChatMessageBuilder({
			serverId: "1",
			serverIdBy: "teaparty@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannel,
			timestamp: "2020-01-01T00:00:00Z",
		});
		builder.sortId = "a0";
		builder.to = borogove.JID.parse("alice@example.com");
		builder.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder.replyTo = [builder.from.asBare()];

		const builder2 = new borogove.ChatMessageBuilder({
			serverId: "2",
			serverIdBy: "teaparty@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannel,
			timestamp: "2020-01-01T00:00:01Z",
		});
		builder2.sortId = "b0";
		builder2.to = borogove.JID.parse("alice@example.com");
		builder2.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder2.replyTo = [builder.from.asBare()];

		const builder3 = new borogove.ChatMessageBuilder({
			serverId: "3",
			serverIdBy: "alice@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannelPrivate,
			timestamp: "2020-01-01T00:00:03Z",
		});
		builder3.sortId = "a1";
		builder3.to = borogove.JID.parse("alice@example.com");
		builder3.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder3.replyTo = [builder.from.asBare()];

		await persistence.storeMessages("alice@example.com", [
			builder2.build(),
			builder3.build(),
			builder.build(),
		]);
		const messages = await persistence.getMessagesAfter(
			"alice@example.com",
			"teaparty@example.com",
		);
		expect(messages.length).toBe(3);
		expect(messages[0].serverId).toBe("1");
		expect(messages[1].serverId).toBe("2");
		expect(messages[2].serverId).toBe("3");
	});

	test("getMessagesAfter some point: MUC come back ordered by sortId, PM by timestamp", async ({
		borogove,
		persistence,
	}) => {
		const builder = new borogove.ChatMessageBuilder({
			serverId: "1",
			serverIdBy: "teaparty@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannel,
			timestamp: "2020-01-01T00:00:01Z",
		});
		builder.sortId = "a0";
		builder.to = borogove.JID.parse("alice@example.com");
		builder.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder.replyTo = [builder.from.asBare()];

		const builder2 = new borogove.ChatMessageBuilder({
			serverId: "2",
			serverIdBy: "teaparty@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannel,
			timestamp: "2020-01-01T00:00:00Z",
		});
		builder2.sortId = "b0";
		builder2.to = borogove.JID.parse("alice@example.com");
		builder2.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder2.replyTo = [builder.from.asBare()];

		const builder3 = new borogove.ChatMessageBuilder({
			serverId: "3",
			serverIdBy: "alice@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannelPrivate,
			timestamp: "2020-01-01T00:00:03Z",
		});
		builder3.sortId = "Z~";
		builder3.to = borogove.JID.parse("alice@example.com");
		builder3.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder3.replyTo = [builder.from.asBare()];

		const builder4 = new borogove.ChatMessageBuilder({
			serverId: "4",
			serverIdBy: "teaparty@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannel,
			timestamp: "2020-01-01T00:00:04Z",
		});
		builder4.sortId = "c0";
		builder4.to = borogove.JID.parse("alice@example.com");
		builder4.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder4.replyTo = [builder.from.asBare()];

		await persistence.storeMessages("alice@example.com", [
			builder2.build(),
			builder4.build(),
			builder3.build(),
			builder.build(),
		]);
		const messages = await persistence.getMessagesAfter(
			"alice@example.com",
			"teaparty@example.com",
			builder.build(),
		);
		expect(messages.length).toBe(3);
		expect(messages[0].serverId).toBe("2");
		expect(messages[1].serverId).toBe("3");
		expect(messages[2].serverId).toBe("4");
	});

	test("getMessagesAfter a PM", async ({ borogove, persistence }) => {
		const builder = new borogove.ChatMessageBuilder({
			serverId: "1",
			serverIdBy: "teaparty@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannel,
			timestamp: "2020-01-01T00:00:00Z",
		});
		builder.sortId = "a0";
		builder.to = borogove.JID.parse("alice@example.com");
		builder.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder.replyTo = [builder.from.asBare()];

		const builder2 = new borogove.ChatMessageBuilder({
			serverId: "2",
			serverIdBy: "teaparty@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannel,
			timestamp: "2020-01-01T00:00:01Z",
		});
		builder2.sortId = "b0";
		builder2.to = borogove.JID.parse("alice@example.com");
		builder2.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder2.replyTo = [builder.from.asBare()];

		const builder3 = new borogove.ChatMessageBuilder({
			serverId: "3",
			serverIdBy: "alice@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannelPrivate,
			timestamp: "2020-01-01T00:00:03Z",
		});
		builder3.sortId = "Z~";
		builder3.to = borogove.JID.parse("alice@example.com");
		builder3.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder3.replyTo = [builder.from.asBare()];

		const builder4 = new borogove.ChatMessageBuilder({
			serverId: "4",
			serverIdBy: "teaparty@example.com",
			senderId: "teaparty@example.com/hatter",
			direction: 0,
			type: borogove.MessageType.MessageChannel,
			timestamp: "2020-01-01T00:00:04Z",
		});
		builder4.sortId = "c0";
		builder4.to = borogove.JID.parse("alice@example.com");
		builder4.from = borogove.JID.parse("teaparty@example.com/hatter");
		builder4.replyTo = [builder.from.asBare()];

		await persistence.storeMessages("alice@example.com", [
			builder2.build(),
			builder4.build(),
			builder3.build(),
			builder.build(),
		]);
		const messages = await persistence.getMessagesAfter(
			"alice@example.com",
			"teaparty@example.com",
			builder3.build(),
		);
		expect(messages.length).toBe(1);
		expect(messages[0].serverId).toBe("4");
	});

	test("updateMessageStatus", async ({ borogove, persistence }) => {
		const builder = new borogove.ChatMessageBuilder({
			localId: "loc1",
			senderId: "alice@example.com",
			direction: 1, // MessageSent
		});
		builder.sortId = "a0";
		builder.to = borogove.JID.parse("hatter@example.com");
		builder.from = borogove.JID.parse("alice@example.com");
		builder.recipients = [builder.to];
		builder.replyTo = [builder.from];
		await persistence.storeMessages("alice@example.com", [builder.build()]);

		const updated = await persistence.updateMessageStatus(
			"alice@example.com",
			"loc1",
			1,
			"Delivered",
		); // MessageDelivered
		expect(updated.status).toBe(1);
		expect(updated.statusText).toBe("Delivered");
	});

	test("removeAccount and listAccounts", async ({ persistence }) => {
		await persistence.storeLogin("alice@example.com", "client1", "Alice", null);
		await persistence.storeLogin("bob@example.com", "client2", "Bob", null);

		const accountsBefore = await persistence.listAccounts();
		await persistence.removeAccount("alice@example.com", true);
		const accountsAfter = await persistence.listAccounts();
		expect(accountsBefore).toContain("alice@example.com");
		expect(accountsBefore).toContain("bob@example.com");
		expect(accountsAfter).not.toContain("alice@example.com");
		expect(accountsAfter).toContain("bob@example.com");
	});

	test("getChatUnreadDetails", async ({ borogove, persistence }) => {
		const chat = Object.create(borogove.DirectChat.prototype);
		chat.chatId = "hatter@example.com";
		chat.readUpToId = "srv1";
		chat.notificationsFiltered = () => false;

		const builder = new borogove.ChatMessageBuilder({
			serverId: "srv1",
			serverIdBy: "hatter@example.com",
			senderId: "hatter@example.com",
			direction: 0,
		});
		builder.sortId = "a0";
		builder.to = borogove.JID.parse("alice@example.com");
		builder.from = borogove.JID.parse("hatter@example.com");
		builder.recipients = [builder.to];
		builder.replyTo = [builder.from];

		const builder2 = new borogove.ChatMessageBuilder({
			serverId: "srv2",
			serverIdBy: "hatter@example.com",
			senderId: "hatter@example.com",
			direction: 0,
		});
		builder2.sortId = "a1";
		builder2.to = borogove.JID.parse("alice@example.com");
		builder2.from = borogove.JID.parse("hatter@example.com");
		builder2.recipients = [builder2.to];
		builder2.replyTo = [builder2.from];

		await persistence.storeMessages("alice@example.com", [
			builder.build(),
			builder2.build(),
		]);
		const unreadDetails = await persistence.getChatUnreadDetails(
			"alice@example.com",
			chat,
		);
		expect(unreadDetails.unreadCount).toBe(1);
		expect(unreadDetails.message.serverId).toBe("srv2");
	});

	test("media storage functions", async ({ borogove, persistence }) => {
		function bufferToByteStream(buffer) {
			let done = false;
			return new ReadableStream({
				type: "bytes",
				async pull(controller) {
					if (done) {
						controller.close();
					} else {
						controller.enqueue(buffer);
						done = true;
					}
				},
			});
		}

		const buffer = new Uint8Array([1, 2, 3]);
		const sha256 = await crypto.subtle.digest("SHA-256", buffer.buffer);
		await persistence.storeMedia("image/png", bufferToByteStream(buffer));
		const hash = new borogove.Hash("sha-256", sha256);
		const hasBefore = await persistence.hasMedia(hash);
		await persistence.removeMedia("sha-256", sha256);
		const hasAfter = await persistence.hasMedia(hash);
		expect(hasBefore).toBe(
			"/.well-known/ni/sha-256/A5BYxvLAy0ksUzsKTRTvd8wPeKvMztUofYShogEc-4E",
		);
		expect(hasAfter).toBe(null);
	});

	test("storeStreamManamagement and getStreamManagement", async ({
		persistence,
	}) => {
		await persistence.storeLogin("alice@example.com", "", "", null); // or updating with SM may not work
		await persistence.storeStreamManagement(
			"alice@example.com",
			new Uint8Array([1, 2, 0, 4]).buffer,
			"ZZ",
		);
		const streamManagement =
			await persistence.getStreamManagement("alice@example.com");
		expect(streamManagement.sm instanceof ArrayBuffer).toBe(true);
		expect(
			streamManagement.sm
				? indexedDB.cmp(
						streamManagement.sm,
						new Uint8Array([1, 2, 0, 4]).buffer,
					)
				: "null",
		).toBe(0);
		expect(streamManagement.sortId).toBe("ZZ");
	});

	test("getMembers hydrates persisted member data", async ({
		borogove,
		persistence,
	}) => {
		const chat = Object.create(borogove.Channel.prototype);
		chat.chatId = "room-members-1@example.com";
		chat.getDisplayName = () => "Tea Room";

		const member = {
			id: "room-members-1@example.com/occ-1",
			displayName: "Alice",
			photoUri: "photo:alice",
			isSelf: false,
			roles: [{ id: "admin", title: "Admin" }],
			jid: borogove.JID.parse("alice@example.com"),
			presence: new Map([
				[
					"laptop",
					borogove.Stanza.parse("<presence><show>away</show></presence>"),
				],
			]),
			chat: { chatId: "alice@example.com" },
		};

		await persistence.storeMembers("alice@example.com", chat.chatId, [member]);
		const [stored] = await persistence.getMembers(
			"alice@example.com",
			chat,
			false,
		);
		expect(stored.id).toBe("room-members-1@example.com/occ-1");
		expect(stored.displayName).toBe("Alice");
		expect(stored.chat?.chatId).toBe("alice@example.com");
		expect(stored.roles.map((r) => r.id)).toEqual(["admin"]);
		expect([...stored.presence.keys()]).toEqual(["laptop"]);
		expect(stored.showPresence).toBe(1);
	});

	test("getMemberDetails returns null for incomplete rows", async ({
		borogove,
		createChannel,
		persistence,
		storeIncompleteMember,
	}) => {
		const chat = createChannel(persistence, "room-members-7@example.com");
		chat.displayName = "A Chat";
		chat.trusted = true;

		await persistence.storeMembers("alice@example.com", chat.chatId, [
			{
				id: "room-members-7@example.com/admin",
				displayName: "Alpha",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "admin", title: "Admin" }],
				jid: borogove.JID.parse("alpha@example.com"),
				presence: new Map([["desk", borogove.Stanza.parse("<presence />")]]),
				chat: { chatId: "alpha@example.com" },
			},
		]);

		await storeIncompleteMember(chat.chatId);
		const details = await persistence.getMemberDetails(
			"alice@example.com",
			chat,
			[
				"room-members-7@example.com/admin",
				"room-members-7@example.com/incomplete",
			],
		);
		expect(details.map((m) => (m ? m.displayName : null))).toEqual([
			"Alpha",
			null,
		]);
	});

	test("storeMemberUpdates merges existing member data", async ({
		borogove,
		persistence,
	}) => {
		const chat = Object.create(borogove.Channel.prototype);
		chat.chatId = "room-members-2@example.com";
		chat.getDisplayName = () => "Tea Room";

		await persistence.storeMembers("alice@example.com", chat.chatId, [
			{
				id: "room-members-2@example.com/occ-1",
				displayName: "Alice",
				photoUri: null,
				isSelf: false,
				roles: [
					{ id: "admin", title: "Admin" },
					{ id: "urn:xmpp:hats:test", title: "Tea Host" },
				],
				jid: borogove.JID.parse("alice@example.com"),
				presence: new Map([["desk", borogove.Stanza.parse("<presence />")]]),
				chat: { chatId: "alice@example.com" },
			},
		]);

		const updates = [
			new borogove.MemberUpdate(
				"room-members-2@example.com/occ-1",
				borogove.JID.parse("alice@example.com"),
				"Alice Cooper",
				false,
				null,
				new Map([["mobile", borogove.Stanza.parse("<presence />")]]),
			),
		];

		const updated = await persistence.storeMemberUpdates(
			"alice@example.com",
			chat,
			updates,
			false,
		);
		expect(updated[0].roles.map((r) => r.id)).toEqual(["urn:xmpp:hats:test"]);
		expect([...updated[0].presence.keys()].sort()).toEqual(["desk", "mobile"]);
		expect(updated[0].displayName).toBe("Alice Cooper");
	});

	test("storeMemberUpdates clears omitted full-list affiliations", async ({
		borogove,
		persistence,
	}) => {
		const chat = Object.create(borogove.Channel.prototype);
		chat.chatId = "room-members-2b@example.com";
		chat.getDisplayName = () => "Tea Room";

		await persistence.storeMembers("alice@example.com", chat.chatId, [
			{
				id: "room-members-2b@example.com/occ-1",
				displayName: "Alice",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "admin", title: "Admin" }],
				jid: borogove.JID.parse("alice@example.com"),
				presence: new Map(),
				chat: { chatId: "alice@example.com" },
			},
			{
				id: "room-members-2b@example.com/occ-2",
				displayName: "Bob",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "owner", title: "Owner" }],
				jid: borogove.JID.parse("bob@example.com"),
				presence: new Map(),
				chat: { chatId: "bob@example.com" },
			},
		]);

		await persistence.storeMemberUpdates(
			"alice@example.com",
			chat,
			[
				new borogove.MemberUpdate(
					"room-members-2b@example.com/occ-1",
					borogove.JID.parse("alice@example.com"),
					"Alice",
					false,
					null,
					new Map(),
				),
			],
			true,
		);
		const members = await persistence.getMembers(
			"alice@example.com",
			chat,
			true,
		);
		expect(members.find((m) => m.id.endsWith("occ-2")).roles).toEqual([]);
	});

	test("storeMemberUpdates matches existing member by true JID", async ({
		borogove,
		persistence,
	}) => {
		const chat1 = Object.create(borogove.Channel.prototype);
		chat1.chatId = "room-members-3@example.com";
		chat1.getDisplayName = () => "Tea Room";
		const chat2 = Object.create(borogove.Channel.prototype);
		chat2.chatId = "room-members-4@example.com";
		chat2.getDisplayName = () => "Other Room";

		await persistence.storeMembers("alice@example.com", chat1.chatId, [
			{
				id: "room-members-3@example.com/occ-1",
				displayName: "Alice",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "admin", title: "Admin" }],
				jid: borogove.JID.parse("alice@example.com"),
				presence: new Map([["desk", borogove.Stanza.parse("<presence />")]]),
				chat: { chatId: "alice@example.com" },
			},
			{
				id: "room-members-4@example.com/occ-1",
				displayName: "Bob",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "admin", title: "Admin" }],
				jid: borogove.JID.parse("bob@example.com"),
				presence: new Map([["phone", borogove.Stanza.parse("<presence />")]]),
				chat: { chatId: "bob@example.com" },
			},
		]);

		await persistence.storeMemberUpdates(
			"alice@example.com",
			chat1,
			[
				new borogove.MemberUpdate(
					null,
					borogove.JID.parse("alice@example.com"),
					"Alice Renamed",
					false,
					null,
					new Map(),
				),
			],
			false,
		);
		const [chat1Member] = await persistence.getMemberDetails(
			"alice@example.com",
			chat1,
			["room-members-3@example.com/occ-1"],
		);
		expect(chat1Member.displayName).toBe("Alice Renamed");
	});

	test("clearMemberPresence only clears the targeted chat", async ({
		borogove,
		persistence,
	}) => {
		const chat1 = Object.create(borogove.Channel.prototype);
		chat1.chatId = "room-members-4a@example.com";
		chat1.getDisplayName = () => "Tea Room";
		const chat2 = Object.create(borogove.Channel.prototype);
		chat2.chatId = "room-members-4b@example.com";
		chat2.getDisplayName = () => "Other Room";

		await persistence.storeMembers("alice@example.com", chat1.chatId, [
			{
				id: "room-members-4a@example.com/occ-1",
				displayName: "Alice",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "admin", title: "Admin" }],
				jid: borogove.JID.parse("alice@example.com"),
				presence: new Map([["desk", borogove.Stanza.parse("<presence />")]]),
				chat: { chatId: "alice@example.com" },
			},
		]);
		await persistence.storeMembers("alice@example.com", chat2.chatId, [
			{
				id: "room-members-4b@example.com/occ-1",
				displayName: "Bob",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "admin", title: "Admin" }],
				jid: borogove.JID.parse("bob@example.com"),
				presence: new Map([["phone", borogove.Stanza.parse("<presence />")]]),
				chat: { chatId: "bob@example.com" },
			},
		]);

		await persistence.clearMemberPresence("alice@example.com", chat1.chatId);
		const [chat1Member] = await persistence.getMemberDetails(
			"alice@example.com",
			chat1,
			["room-members-4a@example.com/occ-1"],
		);
		const [chat2Member] = await persistence.getMemberDetails(
			"alice@example.com",
			chat2,
			["room-members-4b@example.com/occ-1"],
		);
		expect([...chat1Member.presence.keys()]).toEqual([]);
		expect([...chat2Member.presence.keys()]).toEqual(["phone"]);
	});

	test("getMembers filters hidden rows for non-moderators", async ({
		borogove,
		persistence,
	}) => {
		const chat = new borogove.Channel(
			null,
			null,
			persistence,
			"room-members-5@example.com",
		);
		chat.displayName = "Tea Room";
		chat.trusted = true;

		await persistence.storeMembers("alice@example.com", chat.chatId, [
			{
				id: "room-members-5@example.com/owner",
				displayName: "Zulu",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "owner", title: "Owner" }],
				jid: borogove.JID.parse("zulu@example.com"),
				presence: new Map([["desk", borogove.Stanza.parse("<presence />")]]),
				chat: { chatId: "zulu@example.com" },
			},
			{
				id: "room-members-5@example.com/outcast",
				displayName: "Banned",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "outcast", title: "Banned" }],
				jid: borogove.JID.parse("banned@example.com"),
				presence: new Map([["desk", borogove.Stanza.parse("<presence />")]]),
				chat: { chatId: "banned@example.com" },
			},
			{
				id: "room-members-5@example.com/guest-offline",
				displayName: "Guest",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "none", title: "Guest" }],
				jid: borogove.JID.parse("guest@example.com"),
				presence: new Map([
					["desk", borogove.Stanza.parse('<presence type="unavailable" />')],
				]),
				chat: { chatId: "guest@example.com" },
			},
			{
				id: "room-members-5@example.com/guest-offline2",
				displayName: "Guest2",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "none", title: "Guest" }],
				jid: borogove.JID.parse("guest2@example.com"),
				presence: new Map(),
				chat: { chatId: "guest2@example.com" },
			},
			{
				id: "room-members-5@example.com/admin",
				displayName: "Alpha",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "admin", title: "Admin" }],
				jid: borogove.JID.parse("alpha@example.com"),
				presence: new Map([["desk", borogove.Stanza.parse("<presence />")]]),
				chat: { chatId: "alpha@example.com" },
			},
		]);

		const normal = await persistence.getMembers(
			"alice@example.com",
			chat,
			false,
		);
		expect(normal.map((m) => m.displayName)).toEqual(["Zulu", "Alpha"]);
	});

	test("getMembers includes moderator-visible rows", async ({
		borogove,
		persistence,
	}) => {
		const chat = Object.create(borogove.Channel.prototype);
		chat.chatId = "room-members-6@example.com";
		chat.getDisplayName = () => "Tea Room";

		await persistence.storeMembers("alice@example.com", chat.chatId, [
			{
				id: "room-members-6@example.com/owner",
				displayName: "Zulu",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "owner", title: "Owner" }],
				jid: borogove.JID.parse("zulu@example.com"),
				presence: new Map([["desk", borogove.Stanza.parse("<presence />")]]),
				chat: { chatId: "zulu@example.com" },
			},
			{
				id: "room-members-6@example.com/outcast",
				displayName: "Banned",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "outcast", title: "Banned" }],
				jid: borogove.JID.parse("banned@example.com"),
				presence: new Map([["desk", borogove.Stanza.parse("<presence />")]]),
				chat: { chatId: "banned@example.com" },
			},
			{
				id: "room-members-6@example.com/guest-offline",
				displayName: "Guest",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "none", title: "Guest" }],
				jid: borogove.JID.parse("guest@example.com"),
				presence: new Map([
					["desk", borogove.Stanza.parse('<presence type="unavailable" />')],
				]),
				chat: { chatId: "guest@example.com" },
			},
			{
				id: "room-members-6@example.com/admin",
				displayName: "Alpha",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "admin", title: "Admin" }],
				jid: borogove.JID.parse("alpha@example.com"),
				presence: new Map([["desk", borogove.Stanza.parse("<presence />")]]),
				chat: { chatId: "alpha@example.com" },
			},
		]);

		const moderator = await persistence.getMembers(
			"alice@example.com",
			chat,
			true,
		);
		expect(moderator.map((m) => m.displayName)).toEqual([
			"Zulu",
			"Alpha",
			"Banned",
		]);
	});

	test("storeVoiceRequest and listVoiceRequests", async ({
		borogove,
		persistence,
	}) => {
		const chat = Object.create(borogove.Channel.prototype);
		chat.chatId = "room-voice-requests@example.com";
		chat.getDisplayName = () => "Tea Room";

		await persistence.storeMembers("alice@example.com", chat.chatId, [
			{
				id: "room-voice-requests@example.com/occ-1",
				displayName: "Bob",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "none", title: "Participant" }],
				jid: borogove.JID.parse("bob@example.com"),
				presence: new Map([["desk", borogove.Stanza.parse("<presence />")]]),
				chat: { chatId: "bob@example.com" },
			},
			{
				id: "room-voice-requests@example.com/occ-2",
				displayName: "Charlie",
				photoUri: null,
				isSelf: false,
				roles: [{ id: "none", title: "Participant" }],
				jid: borogove.JID.parse("charlie@example.com"),
				presence: new Map([["desk", borogove.Stanza.parse("<presence />")]]),
				chat: { chatId: "charlie@example.com" },
			},
		]);

		await persistence.storeVoiceRequest(
			"alice@example.com",
			chat,
			"bob@example.com",
			true,
		);
		await persistence.storeVoiceRequest(
			"alice@example.com",
			chat,
			"charlie@example.com",
			true,
		);

		const requests1 = await persistence.listVoiceRequests(
			"alice@example.com",
			chat,
		);

		await persistence.storeVoiceRequest(
			"alice@example.com",
			chat,
			"bob@example.com",
			false,
		);

		const requests2 = await persistence.listVoiceRequests(
			"alice@example.com",
			chat,
		);
		expect(requests1.map((m) => m.displayName).sort()).toEqual([
			"Bob",
			"Charlie",
		]);
		expect(requests2.map((m) => m.displayName).sort()).toEqual(["Charlie"]);
	});

	test("getOmemoId returns no ID when none is stored", async ({
		persistence,
	}) => {
		expect(
			await persistence.getOmemoId("omemo-not-found@example.com"),
		).toBeNull();
	});

	test("storeOmemoId stores the ID", async ({ persistence }) => {
		const account = "omemo-existing@example.com";
		const omemoId = 12345;

		await persistence.storeOmemoId(account, omemoId);
		expect(await persistence.getOmemoId(account)).toBe(omemoId);
	});

	test("getOmemoIdentityKey returns null when none is stored", async ({
		persistence,
	}) => {
		expect(
			await persistence.getOmemoIdentityKey(
				"omemo-identity-not-found@example.com",
			),
		).toBeNull();
	});

	test("storeOmemoIdentityKey stores the key pair", async ({ persistence }) => {
		const account = "omemo-identity-existing@example.com";
		const keyPair = makeKeyPair();

		await persistence.storeOmemoIdentityKey(account, keyPair);
		const loadedKeyPair = await persistence.getOmemoIdentityKey(account);

		expectKeyPair(loadedKeyPair, keyPair);
	});

	test("getOmemoDeviceList returns an empty list when none is stored", async ({
		persistence,
	}) => {
		expect(
			await persistence.getOmemoDeviceList(
				"omemo-devices-not-found@example.com",
			),
		).toEqual([]);
	});

	test("storeOmemoDeviceList replaces and clears the device list", async ({
		persistence,
	}) => {
		const identifier = "omemo-devices-existing@example.com";
		const initialDeviceIds = [12345, 67890];
		const replacementDeviceIds = [24680];

		await persistence.storeOmemoDeviceList(identifier, initialDeviceIds);
		const initial = await persistence.getOmemoDeviceList(identifier);
		await persistence.storeOmemoDeviceList(identifier, replacementDeviceIds);
		const afterReplace = await persistence.getOmemoDeviceList(identifier);
		await persistence.storeOmemoDeviceList(identifier, []);
		const afterClear = await persistence.getOmemoDeviceList(identifier);
		expect(initial).toEqual(initialDeviceIds);
		expect(afterReplace).toEqual(replacementDeviceIds);
		expect(afterClear).toEqual([]);
	});

	test("getOmemoPreKey returns null when none is stored", async ({
		persistence,
	}) => {
		const identifier = "omemo-prekey-not-found@example.com";
		const keyId = 1;
		expect(await persistence.getOmemoPreKey(identifier, keyId)).toBeNull();
	});

	test("storeOmemoPreKey stores a removable pre-key", async ({
		persistence,
	}) => {
		const identifier = "omemo-prekey-existing@example.com";
		const keyId = 42;
		const keyPair = makeKeyPair();

		await persistence.storeOmemoPreKey(identifier, keyId, {
			...keyPair,
		});
		const loadedKeyPair = await persistence.getOmemoPreKey(identifier, keyId);
		await persistence.removeOmemoPreKey(identifier, keyId);
		const afterRemove = await persistence.getOmemoPreKey(identifier, keyId);
		expectKeyPair(loadedKeyPair, keyPair);
		expect(afterRemove).toBeNull();
	});

	test("getOmemoPreKeys lists stored pre-keys", async ({ persistence }) => {
		const identifier = "omemo-prekeys-existing@example.com";
		const preKeys = [
			{
				keyId: 2,
				keyPair: makeKeyPair(),
			},
			{
				keyId: 3,
				keyPair: makeKeyPair(),
			},
		];

		for (const preKey of preKeys) {
			await persistence.storeOmemoPreKey(
				identifier,
				preKey.keyId,
				preKey.keyPair,
			);
		}
		const loaded = await persistence.getOmemoPreKeys(identifier);
		expect(loaded).toEqual(preKeys);
	});

	test("storeOmemoSignedPreKey and getOmemoSignedPreKey", async ({
		persistence,
	}) => {
		const identifier = "omemo-signed-prekey-existing@example.com";
		const keyId = 42;
		const signedPreKey = {
			keyId,
			keyPair: makeKeyPair(),
			signature: makeKey(),
		};

		await persistence.storeOmemoSignedPreKey(identifier, {
			keyId: signedPreKey.keyId,
			keyPair: signedPreKey.keyPair,
			signature: signedPreKey.signature,
		});
		const loaded = await persistence.getOmemoSignedPreKey(
			identifier,
			signedPreKey.keyId,
		);
		expect(loaded.keyId).toBe(keyId);
		expectKeyPair(loaded.keyPair, signedPreKey.keyPair);
		expectKey(loaded.signature, signedPreKey.signature);
	});

	test("getOmemoSignedPreKey returns null when none is stored", async ({
		persistence,
	}) => {
		expect(
			await persistence.getOmemoSignedPreKey(
				"omemo-signed-prekey-not-found@example.com",
				1,
			),
		).toBeNull();
	});

	test("getOmemoContactIdentityKey returns null when none is stored", async ({
		persistence,
	}) => {
		expect(
			await persistence.getOmemoContactIdentityKey(
				"omemo-contact-not-found@example.com",
				"contact@example.com/1",
			),
		).toBeNull();
	});

	test("storeOmemoContactIdentityKey and getOmemoContactIdentityKey", async ({
		persistence,
	}) => {
		const account = "omemo-contact-existing@example.com";
		const address = "contact@example.com/1";
		const identityKey = makeKey();

		await persistence.storeOmemoContactIdentityKey(
			account,
			address,
			identityKey,
		);
		const loaded = await persistence.getOmemoContactIdentityKey(
			account,
			address,
		);
		expect(loaded).toEqual(identityKey);
	});

	test("getOmemoSession returns null when none is stored", async ({
		persistence,
	}) => {
		expect(
			await persistence.getOmemoSession(
				"omemo-session-not-found@example.com",
				"contact@example.com/1",
			),
		).toBeNull();
	});

	test("getOmemoMetadata returns null when none is stored", async ({
		persistence,
	}) => {
		expect(
			await persistence.getOmemoMetadata(
				"omemo-metadata-not-found@example.com",
				"contact@example.com/1",
			),
		).toBeNull();
	});

	test("storeOmemoMetadata and getOmemoMetadata", async ({ persistence }) => {
		const account = "omemo-metadata-existing@example.com";
		const address = "contact@example.com/1";
		const metadata = {
			receivedSessionMessageOk: true,
			lastMessageDecryptedOk: false,
			sentKeyExchange: true,
		};

		await persistence.storeOmemoMetadata(account, address, metadata);
		expect(await persistence.getOmemoMetadata(account, address)).toEqual(
			metadata,
		);
	});

	test("storeOmemoSession, getOmemoSession, and removeOmemoSession", async ({
		persistence,
	}) => {
		const account = "omemo-session-existing@example.com";
		const address = "contact@example.com/1";
		const session = '{"sessions":{},"version":"v1"}';

		await persistence.storeOmemoSession(account, address, session);
		const loaded = await persistence.getOmemoSession(account, address);
		await persistence.removeOmemoSession(account, address);
		const afterRemove = await persistence.getOmemoSession(account, address);
		expect(loaded).toEqual(session);
		expect(afterRemove).toBeNull();
	});

	test("hydrate message with incomplete replyToMessage", async ({
		borogove,
		persistence,
	}) => {
		const builder = new borogove.ChatMessageBuilder({
			serverId: "parent",
			serverIdBy: "alice@example.com",
			localId: "loc1",
			senderId: "hatter@example.com",
			direction: 0,
		});
		builder.sortId = "a0";
		builder.to = borogove.JID.parse("alice@example.com");
		builder.from = borogove.JID.parse("hatter@example.com");
		builder.recipients = [builder.to];
		builder.replyTo = [builder.from];
		const parentStub = builder.build();

		builder.setBody(borogove.Html.text("Hello"));
		const parentMsg = builder.build();

		const builder2 = new borogove.ChatMessageBuilder({
			serverId: "child",
			serverIdBy: "alice@example.com",
			localId: "loc2",
			senderId: "hatter@example.com",
			direction: 0,
		});
		builder2.sortId = "a1";
		builder2.to = borogove.JID.parse("alice@example.com");
		builder2.from = borogove.JID.parse("hatter@example.com");
		builder2.recipients = [builder2.to];
		builder2.replyTo = [builder2.from];
		builder2.replyToMessage = parentStub;
		const childMsg = builder2.build();

		await persistence.storeMessages("alice@example.com", [parentMsg]);
		const [childStored] = await persistence.storeMessages("alice@example.com", [
			childMsg,
		]);
		expect(childStored.replyToMessage.body().toPlainText()).toBe("Hello");
	});

	test("allows rescinding a custom reaction", async ({
		borogove,
		persistence,
	}) => {
		const account = "alice@example.com";
		const chatId = "hatter@example.com";
		const targetLocalId = "target-message";
		const reactionMessageId = "reaction-message";
		const timestamp = "2026-09-09T12:00:00Z";

		const targetBuilder = new borogove.ChatMessageBuilder({
			localId: targetLocalId,
			senderId: account,
			direction: 1,
		});
		targetBuilder.sortId = "a0";
		targetBuilder.to = borogove.JID.parse(chatId);
		targetBuilder.from = borogove.JID.parse(account);
		targetBuilder.recipients = [targetBuilder.to];
		targetBuilder.replyTo = [targetBuilder.from];

		await persistence.storeMessages(account, [targetBuilder.build()]);

		const reaction = new borogove.CustomEmojiReaction(
			account,
			timestamp,
			"tada",
			"https://example.com/tada.png",
			reactionMessageId,
		);
		const update = new borogove.ReactionUpdate(
			reactionMessageId,
			null,
			null,
			targetLocalId,
			chatId,
			account,
			timestamp,
			[reaction],
			borogove.ReactionUpdateKind.AppendReactions,
		);

		const withReaction = await persistence.storeReaction(account, update);

		const emptyBuilder = new borogove.ChatMessageBuilder({
			localId: reactionMessageId,
			senderId: account,
			direction: 1,
		});
		emptyBuilder.sortId = "a1";
		emptyBuilder.to = borogove.JID.parse(chatId);
		emptyBuilder.from = borogove.JID.parse(account);
		emptyBuilder.recipients = [emptyBuilder.to];
		emptyBuilder.replyTo = [emptyBuilder.from];

		const [stored] = await persistence.storeMessages(account, [
			emptyBuilder.build(),
		]);

		expect([...withReaction!.reactions.keys()]).toEqual([
			"https://example.com/tada.png",
		]);
		expect([...stored.reactions.keys()]).toEqual([]);
	});
}

type TestKeyPair = {
	privKey: ArrayBuffer;
	pubKey: ArrayBuffer;
};

const makeKey = (): ArrayBuffer => {
	const bytes = new Uint8Array(32);
	crypto.getRandomValues(bytes);
	return bytes.buffer;
};

const makeKeyPair = (): TestKeyPair => ({
	privKey: makeKey(),
	pubKey: makeKey(),
});

function expectKeyPair(actual: TestKeyPair, expected: TestKeyPair) {
	expectKey(actual.privKey, expected.privKey);
	expectKey(actual.pubKey, expected.pubKey);
}

function expectKey(actual: ArrayBuffer, expected: ArrayBuffer) {
	expect(actual).toEqual(expected);
}
