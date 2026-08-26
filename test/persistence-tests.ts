import { idbTest, sqliteTest, expect } from "./browser-test";
import { randomBytes } from "node:crypto";

type PersistenceTest = typeof idbTest | typeof sqliteTest;

export function sharedPersistenceTests(test: PersistenceTest) {
	test("storeChats and getChats", async ({ page, borogove, persistence }) => {
		const result = await page.evaluate(
			async ({ borogove, persistence }) => {
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
				return {
					length: chats.length,
					chatId: chats[0]?.chatId,
					displayName: chats[0]?.displayName,
					trusted: chats[0]?.trusted,
					klass: chats[0]?.klass,
					channelSubject: chats[0]?.threads?.get(null),
					threadSubject: chats[0]?.threads?.get("thread-1"),
				};
			},
			{ borogove, persistence },
		);

		expect(result.length).toBe(1);
		expect(result.chatId).toBe("hatter@example.com");
		expect(result.displayName).toBe("The Mad Hatter");
		expect(result.trusted).toBe(true);
		expect(result.klass).toBe("DirectChat");
		expect(result.channelSubject).toBe("Tea Time");
		expect(result.threadSubject).toBe("Introductions");
	});

	test("storeChats and getChats with status", async ({ page, borogove, persistence }) => {
		const result = await page.evaluate(
			async ({ borogove, persistence }) => {
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
				return {
					length: chats.length,
					chatId: chats[0]?.chatId,
					statusEmoji: chats[0]?.status?.emoji,
					statusText: chats[0]?.status?.text,
				};
			},
			{ borogove, persistence },
		);

		expect(result.length).toBe(1);
		expect(result.chatId).toBe("hatter@example.com");
		expect(result.statusEmoji).toBe("🎩");
		expect(result.statusText).toBe("Time for tea!");
	});

	test("getChats uses member presence for direct chats", async ({ page, borogove, persistence }) => {
		const result = await page.evaluate(
			async ({ borogove, persistence }) => {
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
						presence: new Map([
							["phone", borogove.Stanza.parse("<presence />")],
						]),
						chat: null,
					},
				]);
				const [stored] = await persistence.getChats("alice@example.com");
				return [...stored.presence.keys()].sort();
			},
			{ borogove, persistence },
		);

		expect(result).toEqual(["phone"]);
	});

	test("getChats hydrates membersForName and mavUntil from members", async ({
		page,
		borogove,
		persistence,
		createChannel,
	}) => {
		const result = await page.evaluate(
			async ({ borogove, persistence, createChannel }) => {
				const chat = createChannel(
					persistence,
					"room-chat-hydrate@example.com",
				);
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
						presence: new Map([
							["desk", borogove.Stanza.parse("<presence />")],
						]),
						chat: null,
					},
					{
						id: `${chat.chatId}/zulu`,
						displayName: "Zulu",
						photoUri: null,
						isSelf: false,
						roles: [{ id: "admin", title: "Admin" }],
						jid: borogove.JID.parse("zulu@example.com"),
						presence: new Map([
							["desk", borogove.Stanza.parse("<presence />")],
						]),
						chat: { chatId: "zulu@example.com" },
					},
					{
						id: `${chat.chatId}/alpha`,
						displayName: "Alpha",
						photoUri: null,
						isSelf: false,
						roles: [],
						jid: borogove.JID.parse("alpha@example.com"),
						presence: new Map([
							["desk", borogove.Stanza.parse("<presence />")],
						]),
						chat: { chatId: "alpha@example.com" },
					},
					{
						id: `${chat.chatId}/hidden`,
						displayName: "Hidden",
						photoUri: null,
						isSelf: false,
						roles: [{ id: "none", title: "Guest" }],
						jid: borogove.JID.parse("hidden@example.com"),
						presence: new Map([
							["desk", borogove.Stanza.parse("<presence />")],
						]),
						chat: { chatId: "hidden@example.com" },
					},
				]);
				const [stored] = await persistence.getChats("alice@example.com");
				return {
					mavUntil: stored.mavUntil,
					membersForName: stored.membersForName.map((m) => m.displayName),
					presenceKeys: [...stored.presence.keys()].sort(),
				};
			},
			{ borogove, persistence, createChannel },
		);

		expect(result.mavUntil).toBe("2024-05-01T12:00:00Z");
		expect(result.membersForName).toEqual(["Alpha", "Zulu"]);
		expect(result.presenceKeys).toEqual(["desk"]);
	});


	test("hydrate replyToMessage for groupchats", async ({ page, borogove, persistence }) => {
		const result = await page.evaluate(
			async ({ borogove, persistence }) => {
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
				const [childStored] = await persistence.storeMessages(
					"alice@example.com",
					[builder2.build()],
				);
				return childStored.replyToMessage.body().toPlainText();
			},
			{ borogove, persistence },
		);

		expect(result).toBe("Hello");
	});

	test("getMessage by serverId and localId", async ({
		page,
		borogove,
		persistence,
	}) => {
		const result = await page.evaluate(
			async ({ borogove, persistence }) => {
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

				return {
					byServerId: byServerId
						? { serverId: byServerId.serverId, localId: byServerId.localId }
						: null,
					byLocalId: byLocalId
						? { serverId: byLocalId.serverId, localId: byLocalId.localId }
						: null,
				};
			},
			{ borogove, persistence },
		);

		expect(result.byServerId).not.toBeNull();
		expect(result.byServerId.serverId).toBe("srv1");
		expect(result.byLocalId).not.toBeNull();
		expect(result.byLocalId.localId).toBe("loc1");
	});

	test("storeReaction", async ({ page, borogove, persistence }) => {
		const result = await page.evaluate(
			async ({ borogove, persistence }) => {
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

				const msg = await persistence.storeReaction(
					"alice@example.com",
					update,
				);
				return {
					reactions: [...msg.reactions.entries()].map(([k, v]) => ({
						key: k,
						count: v.length,
					})),
				};
			},
			{ borogove, persistence },
		);

		expect(result.reactions.length).toBe(1);
		expect(result.reactions[0].key).toBe("👍");
		expect(result.reactions[0].count).toBe(1);
	});

	test("searchMessages", async ({ page, borogove, persistence }) => {
		const result = await page.evaluate(
			async ({ borogove, persistence }) => {
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
				return results.map((m) => m.text);
			},
			{ borogove, persistence },
		);

		expect(result.length).toBe(1);
		expect(result[0]).toBe("Hello world");
	});

	test("1:1 come back ordered by sortId", async ({ page, borogove, persistence }) => {
		const result = await page.evaluate(async ({ borogove, persistence }) => {
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

			return await persistence.getMessagesBefore(
				"alice@example.com",
				"hatter@example.com",
			);
		}, { borogove, persistence });

		expect(result.length).toBe(2);
		expect(result[0].serverId).toBe("1");
		expect(result[1].serverId).toBe("2");
	});

	test("getMessagesBefore the end: MUC come back ordered by sortId, PM by timestamp", async ({
		page,
		borogove,
		persistence,
	}) => {
		const result = await page.evaluate(async ({ borogove, persistence }) => {
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

			return await persistence.getMessagesBefore(
				"alice@example.com",
				"teaparty@example.com",
			);
		}, { borogove, persistence });

		expect(result.length).toBe(3);
		expect(result[0].serverId).toBe("1");
		expect(result[1].serverId).toBe("2");
		expect(result[2].serverId).toBe("3");
	});

	test("getMessagesBefore some point: MUC come back ordered by sortId, PM by timestamp", async ({
		page,
		borogove,
		persistence,
	}) => {
		const result = await page.evaluate(async ({ borogove, persistence }) => {
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

			return await persistence.getMessagesBefore(
				"alice@example.com",
				"teaparty@example.com",
				builder4.build(),
			);
		}, { borogove, persistence });

		expect(result.length).toBe(3);
		expect(result[0].serverId).toBe("1");
		expect(result[1].serverId).toBe("2");
		expect(result[2].serverId).toBe("3");
	});

	test("getMessagesBefore a PM", async ({ page, borogove, persistence }) => {
		const result = await page.evaluate(async ({ borogove, persistence }) => {
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

			return await persistence.getMessagesBefore(
				"alice@example.com",
				"teaparty@example.com",
				builder3.build(),
			);
		}, { borogove, persistence });

		expect(result.length).toBe(2);
		expect(result[0].serverId).toBe("1");
		expect(result[1].serverId).toBe("2");
	});

	test("getMessagesAfter the start: MUC come back ordered by sortId, PM by timestamp", async ({
		page,
		borogove,
		persistence,
	}) => {
		const result = await page.evaluate(async ({ borogove, persistence }) => {
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

			return await persistence.getMessagesAfter(
				"alice@example.com",
				"teaparty@example.com",
			);
		}, { borogove, persistence });

		expect(result.length).toBe(3);
		expect(result[0].serverId).toBe("1");
		expect(result[1].serverId).toBe("2");
		expect(result[2].serverId).toBe("3");
	});

	test("getMessagesAfter some point: MUC come back ordered by sortId, PM by timestamp", async ({
		page,
		borogove,
		persistence,
	}) => {
		const result = await page.evaluate(async ({ borogove, persistence }) => {
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

			return await persistence.getMessagesAfter(
				"alice@example.com",
				"teaparty@example.com",
				builder.build(),
			);
		}, { borogove, persistence });

		expect(result.length).toBe(3);
		expect(result[0].serverId).toBe("2");
		expect(result[1].serverId).toBe("3");
		expect(result[2].serverId).toBe("4");
	});

	test("getMessagesAfter a PM", async ({ page, borogove, persistence }) => {
		const result = await page.evaluate(async ({ borogove, persistence }) => {
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

			return await persistence.getMessagesAfter(
				"alice@example.com",
				"teaparty@example.com",
				builder3.build(),
			);
		}, { borogove, persistence });

		expect(result.length).toBe(1);
		expect(result[0].serverId).toBe("4");
	});

	test("updateMessageStatus", async ({ page, borogove, persistence }) => {
		const result = await page.evaluate(async ({ borogove, persistence }) => {
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
			return { status: updated.status, statusText: updated.statusText };
		}, { borogove, persistence });

		expect(result.status).toBe(1);
		expect(result.statusText).toBe("Delivered");
	});

	test("removeAccount and listAccounts", async ({ page, borogove, persistence }) => {
		const result = await page.evaluate(async ({ borogove, persistence }) => {
			await persistence.storeLogin("alice@example.com", "client1", "Alice", null);
			await persistence.storeLogin("bob@example.com", "client2", "Bob", null);

			const accountsBefore = await persistence.listAccounts();
			await persistence.removeAccount("alice@example.com", true);
			const accountsAfter = await persistence.listAccounts();

			return { accountsBefore, accountsAfter };
		}, { borogove, persistence });

		expect(result.accountsBefore).toContain("alice@example.com");
		expect(result.accountsBefore).toContain("bob@example.com");
		expect(result.accountsAfter).not.toContain("alice@example.com");
		expect(result.accountsAfter).toContain("bob@example.com");
	});

	test("getChatUnreadDetails", async ({ page, borogove, persistence }) => {
		const result = await page.evaluate(async ({ borogove, persistence }) => {
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

			return await persistence.getChatUnreadDetails("alice@example.com", chat);
		}, { borogove, persistence });

		expect(result.unreadCount).toBe(1);
		expect(result.message.serverId).toBe("srv2");
	});

	test("media storage functions", async ({ page, borogove, persistence }) => {
		const result = await page.evaluate(async ({ borogove, persistence }) => {
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

			return { hasBefore, hasAfter };
		}, { borogove, persistence });

		expect(result.hasBefore).toBe(
			"/.well-known/ni/sha-256/A5BYxvLAy0ksUzsKTRTvd8wPeKvMztUofYShogEc-4E",
		);
		expect(result.hasAfter).toBe(null);
	});

	test("storeStreamManamagement and getStreamManagement", async ({ page, borogove, persistence }) => {
		const result = await page.evaluate(async ({ borogove, persistence }) => {
			await persistence.storeLogin("alice@example.com", "", "", null); // or updating with SM may not work
			await persistence.storeStreamManagement(
				"alice@example.com",
				new Uint8Array([1, 2, 0, 4]).buffer,
				"ZZ",
			);
			const result = await persistence.getStreamManagement("alice@example.com");
			return {
				smIsArrayBuffer: result.sm instanceof ArrayBuffer,
				smIsEq: result.sm
					? indexedDB.cmp(result.sm, new Uint8Array([1, 2, 0, 4]).buffer)
					: "null",
				sortId: result.sortId,
			};
		}, { borogove, persistence });

		expect(result.smIsEq).toBe(0);
		expect(result.smIsArrayBuffer).toBe(true);
		expect(result.sortId).toBe("ZZ");
	});

	test("getMembers hydrates persisted member data", async ({ page, borogove, persistence }) => {
		const result = await page.evaluate(async ({ borogove, persistence }) => {
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

			return {
				id: stored.id,
				displayName: stored.displayName,
				chatId: stored.chat?.chatId,
				roleIds: stored.roles.map((r) => r.id),
				presenceKeys: [...stored.presence.keys()],
				showPresence: stored.showPresence,
			};
		}, { borogove, persistence });

		expect(result.id).toBe("room-members-1@example.com/occ-1");
		expect(result.displayName).toBe("Alice");
		expect(result.chatId).toBe("alice@example.com");
		expect(result.roleIds).toEqual(["admin"]);
		expect(result.presenceKeys).toEqual(["laptop"]);
		expect(result.showPresence).toBe(1);
	});

	test("getMemberDetails returns null for incomplete rows", async ({
		page,
		borogove,
		createChannel,
		persistence,
		storeIncompleteMember,
	}) => {
		const result = await page.evaluate(
			async ({
				borogove,
				createChannel,
				persistence,
				storeIncompleteMember,
			}) => {
				const chat = createChannel(
					persistence,
					"room-members-7@example.com",
				);
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
						presence: new Map([
							["desk", borogove.Stanza.parse("<presence />")],
						]),
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
				return details.map((m) => (m ? m.displayName : null));
			},
			{
				borogove,
				createChannel,
				persistence,
				storeIncompleteMember,
			},
		);

		expect(result).toEqual(["Alpha", null]);
	});

	test("storeMemberUpdates merges existing member data", async ({ page, borogove, persistence }) => {
		const result = await page.evaluate(async ({ borogove, persistence }) => {
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

			return {
				updatedRoleIds: updated[0].roles.map((r) => r.id),
				updatedPresenceKeys: [...updated[0].presence.keys()].sort(),
				updatedDisplayName: updated[0].displayName,
			};
		}, { borogove, persistence });

		expect(result.updatedRoleIds).toEqual(["urn:xmpp:hats:test"]);
		expect(result.updatedPresenceKeys).toEqual(["desk", "mobile"]);
		expect(result.updatedDisplayName).toBe("Alice Cooper");
	});

	test("storeMemberUpdates clears omitted full-list affiliations", async ({
		page,
		borogove,
		persistence,
	}) => {
		const result = await page.evaluate(async ({ borogove, persistence }) => {
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

			return members.find((m) => m.id.endsWith("occ-2")).roles.map((r) => r.id);
		}, { borogove, persistence });

		expect(result).toEqual([]);
	});

	test("storeMemberUpdates matches existing member by true JID", async ({
		page,
		borogove,
		persistence,
	}) => {
		const result = await page.evaluate(async ({ borogove, persistence }) => {
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

			return chat1Member.displayName;
		}, { borogove, persistence });

		expect(result).toBe("Alice Renamed");
	});

	test("clearMemberPresence only clears the targeted chat", async ({ page, borogove, persistence }) => {
		const result = await page.evaluate(async ({ borogove, persistence }) => {
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

			return {
				chat1PresenceKeys: [...chat1Member.presence.keys()],
				chat2PresenceKeys: [...chat2Member.presence.keys()],
			};
		}, { borogove, persistence });

		expect(result.chat1PresenceKeys).toEqual([]);
		expect(result.chat2PresenceKeys).toEqual(["phone"]);
	});

	test("getMembers includes moderator-visible rows", async ({ page, borogove, persistence }) => {
		const result = await page.evaluate(async ({ borogove, persistence }) => {
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
			return moderator.map((m) => m.displayName);
		}, { borogove, persistence });

		expect(result).toEqual(["Zulu", "Alpha", "Banned"]);
	});

	test("storeVoiceRequest and listVoiceRequests", async ({ page, borogove, persistence }) => {
		const result = await page.evaluate(async ({ borogove, persistence }) => {
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
				}
			]);

			await persistence.storeVoiceRequest("alice@example.com", chat, "bob@example.com", true);
			await persistence.storeVoiceRequest("alice@example.com", chat, "charlie@example.com", true);

			const requests1 = await persistence.listVoiceRequests("alice@example.com", chat);

			await persistence.storeVoiceRequest("alice@example.com", chat, "bob@example.com", false);

			const requests2 = await persistence.listVoiceRequests("alice@example.com", chat);

			return {
				requests1: requests1.map((m) => m.displayName).sort(),
				requests2: requests2.map((m) => m.displayName).sort(),
			};
		}, { borogove, persistence });

		expect(result.requests1).toEqual(["Bob", "Charlie"]);
		expect(result.requests2).toEqual(["Charlie"]);
	});

	test("getOmemoId returns no ID when none is stored", async ({
		page,
		persistence,
	}) => {
		const result = await page.evaluate(
			async (persistence) =>
				persistence.getOmemoId("omemo-not-found@example.com"),
			persistence,
		);

		expect(result).toBeNull();
	});

	test("storeOmemoId stores the ID", async ({
		page,
		persistence,
	}) => {
		const account = "omemo-existing@example.com";
		const omemoId = 12345;
		const result = await page.evaluate(
			async ({ persistence, account, omemoId }) => {
				await persistence.storeOmemoId(account, omemoId);
				return persistence.getOmemoId(account);
			},
			{ persistence, account, omemoId },
		);

		expect(result).toBe(omemoId);
	});

	test("getOmemoIdentityKey returns null when none is stored", async ({
		page,
		persistence,
	}) => {
		const result = await page.evaluate(
			async (persistence) =>
				persistence.getOmemoIdentityKey(
					"omemo-identity-not-found@example.com",
				),
			persistence,
		);

		expect(result).toBeNull();
	});

	test("storeOmemoIdentityKey stores the key pair", async ({
		page,
		pageHelpers,
		persistence,
	}) => {
		const account = "omemo-identity-existing@example.com";
		const keyPair = makeKeyPair();

		const result = await page.evaluate(
			async ({ persistence, account, keyPair, pageHelpers }) => {
				await persistence.storeOmemoIdentityKey(
					account,
					pageHelpers.keyPairToBuffers(keyPair),
				);
				const loadedKeyPair = await persistence.getOmemoIdentityKey(account);

				return pageHelpers.buffersToKeyPair(loadedKeyPair);
			},
			{ persistence, account, keyPair, pageHelpers },
		);

		expectKeyPair(result, keyPair);
	});

	test("getOmemoDeviceList returns an empty list when none is stored", async ({
		page,
		persistence,
	}) => {
		const result = await page.evaluate(
			async (persistence) =>
				persistence.getOmemoDeviceList(
					"omemo-devices-not-found@example.com",
				),
			persistence,
		);

		expect(result).toEqual([]);
	});

	test("storeOmemoDeviceList replaces and clears the device list", async ({
		page,
		persistence,
	}) => {
		const identifier = "omemo-devices-existing@example.com";
		const initialDeviceIds = [12345, 67890];
		const replacementDeviceIds = [24680];
		const result = await page.evaluate(
			async ({
				persistence,
				identifier,
				initialDeviceIds,
				replacementDeviceIds,
			}) => {
				await persistence.storeOmemoDeviceList(identifier, initialDeviceIds);
				const initial = await persistence.getOmemoDeviceList(identifier);
				await persistence.storeOmemoDeviceList(
					identifier,
					replacementDeviceIds,
				);
				const afterReplace = await persistence.getOmemoDeviceList(identifier);
				await persistence.storeOmemoDeviceList(identifier, []);
				const afterClear = await persistence.getOmemoDeviceList(identifier);

				return { initial, afterReplace, afterClear };
			},
			{
				persistence,
				identifier,
				initialDeviceIds,
				replacementDeviceIds,
			},
		);

		expect(result.initial).toEqual(initialDeviceIds);
		expect(result.afterReplace).toEqual(replacementDeviceIds);
		expect(result.afterClear).toEqual([]);
	});

	test("getOmemoPreKey returns null when none is stored", async ({
		page,
		persistence,
	}) => {
		const identifier = "omemo-prekey-not-found@example.com";
		const keyId = 1;
		const result = await page.evaluate(
			async ({ persistence, identifier, keyId }) =>
				persistence.getOmemoPreKey(identifier, keyId),
			{ persistence, identifier, keyId },
		);

		expect(result).toBeNull();
	});

	test("storeOmemoPreKey stores a removable pre-key", async ({
		page,
		pageHelpers,
		persistence,
	}) => {
		const identifier = "omemo-prekey-existing@example.com";
		const keyId = 42;
		const keyPair = makeKeyPair();
		const result = await page.evaluate(
			async ({ persistence, identifier, keyId, keyPair, pageHelpers }) => {
				await persistence.storeOmemoPreKey(identifier, keyId, {
					...pageHelpers.keyPairToBuffers(keyPair),
				});
				const loadedKeyPair = await persistence.getOmemoPreKey(
					identifier,
					keyId,
				);
				await persistence.removeOmemoPreKey(identifier, keyId);
				const afterRemove = await persistence.getOmemoPreKey(identifier, keyId);

				return { loadedKeyPair: pageHelpers.buffersToKeyPair(loadedKeyPair), afterRemove };
			},
			{ persistence, identifier, keyId, keyPair, pageHelpers },
		);

		expectKeyPair(result.loadedKeyPair, keyPair);
		expect(result.afterRemove).toBeNull();
	});

	test("getOmemoPreKeys lists stored pre-keys", async ({
		page,
		pageHelpers,
		persistence,
	}) => {
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
		const result = await page.evaluate(
			async ({ persistence, identifier, preKeys, pageHelpers }) => {
				for (const preKey of preKeys) {
					await persistence.storeOmemoPreKey(
						identifier,
						preKey.keyId,
						pageHelpers.keyPairToBuffers(preKey.keyPair),
					);
				}
				const loaded = await persistence.getOmemoPreKeys(identifier);
				return loaded.map((preKey) => ({
					keyId: preKey.keyId,
					keyPair: pageHelpers.buffersToKeyPair(preKey.keyPair),
				}));
			},
			{ persistence, identifier, preKeys, pageHelpers },
		);

		expect(result).toEqual(preKeys);
	});

	test("storeOmemoSignedPreKey and getOmemoSignedPreKey", async ({
		page,
		pageHelpers,
		persistence,
	}) => {
		const identifier = "omemo-signed-prekey-existing@example.com";
		const keyId = 42;
		const signedPreKey = {
			keyId,
			keyPair: makeKeyPair(),
			signature: makeKey(),
		};
		const result = await page.evaluate(
			async ({ persistence, identifier, signedPreKey, pageHelpers }) => {
				await persistence.storeOmemoSignedPreKey(identifier, {
					keyId: signedPreKey.keyId,
					keyPair: pageHelpers.keyPairToBuffers(signedPreKey.keyPair),
					signature: pageHelpers.keyToBuffer(signedPreKey.signature),
				});
				const loaded = await persistence.getOmemoSignedPreKey(
					identifier,
					signedPreKey.keyId,
				);

				return {
					keyId: loaded.keyId,
					keyPair: pageHelpers.buffersToKeyPair(loaded.keyPair),
					signature: pageHelpers.bufferToKey(loaded.signature),
				};
			},
			{ persistence, identifier, signedPreKey, pageHelpers },
		);

		expect(result.keyId).toBe(keyId);
		expectKeyPair(result.keyPair, signedPreKey.keyPair);
		expectKey(result.signature, signedPreKey.signature);
	});

	test("getOmemoSignedPreKey returns null when none is stored", async ({
		page,
		persistence,
	}) => {
		const result = await page.evaluate(
			async ({ persistence }) =>
				persistence.getOmemoSignedPreKey(
					"omemo-signed-prekey-not-found@example.com",
					1,
				),
			{ persistence },
		);

		expect(result).toBeNull();
	});

	test("getOmemoContactIdentityKey returns null when none is stored", async ({
		page,
		persistence,
	}) => {
		const result = await page.evaluate(
			async ({ persistence }) =>
				persistence.getOmemoContactIdentityKey(
					"omemo-contact-not-found@example.com",
					"contact@example.com/1",
				),
			{ persistence },
		);

		expect(result).toBeNull();
	});

	test("storeOmemoContactIdentityKey and getOmemoContactIdentityKey", async ({
		page,
		pageHelpers,
		persistence,
	}) => {
		const account = "omemo-contact-existing@example.com";
		const address = "contact@example.com/1";
		const identityKey = makeKey();
		const result = await page.evaluate(
			async ({ persistence, account, address, identityKey, pageHelpers }) => {
				await persistence.storeOmemoContactIdentityKey(
					account,
					address,
					pageHelpers.keyToBuffer(identityKey),
				);
				const loaded = await persistence.getOmemoContactIdentityKey(
					account,
					address,
				);
				return pageHelpers.bufferToKey(loaded);
			},
			{ persistence, account, address, identityKey, pageHelpers },
		);

		expect(result).toEqual(identityKey);
	});

	test("getOmemoSession returns null when none is stored", async ({
		page,
		persistence,
	}) => {
		const result = await page.evaluate(
			async ({ persistence }) =>
				persistence.getOmemoSession(
					"omemo-session-not-found@example.com",
					"contact@example.com/1",
				),
			{ persistence },
		);

		expect(result).toBeNull();
	});

	test("storeOmemoSession, getOmemoSession, and removeOmemoSession", async ({
		page,
		persistence,
	}) => {
		const account = "omemo-session-existing@example.com";
		const address = "contact@example.com/1";
		const session = '{"sessions":{},"version":"v1"}';
		const result = await page.evaluate(
			async ({ persistence, account, address, session }) => {
				await persistence.storeOmemoSession(account, address, session);
				const loaded = await persistence.getOmemoSession(account, address);
				await persistence.removeOmemoSession(account, address);
				const afterRemove = await persistence.getOmemoSession(account, address);

				return {
					loaded,
					afterRemove,
				};
			},
			{ persistence, account, address, session },
		);

		expect(result.loaded).toEqual(session);
		expect(result.afterRemove).toBeNull();
	});
}

type TestKeyPair = {
	privKey: number[];
	pubKey: number[];
};

const makeKey = (): number[] => [...randomBytes(32)];

const makeKeyPair = (): TestKeyPair => ({
	privKey: makeKey(),
	pubKey: makeKey().reverse(),
});

function expectKeyPair(
	actual: TestKeyPair,
	expected: TestKeyPair,
) {
	expectKey(actual.privKey, expected.privKey);
	expectKey(actual.pubKey, expected.pubKey);
}

function expectKey(actual: number[], expected: number[]) {
	expect(actual).toEqual(expected);
}
