import { test, expect } from "@playwright/test";
import fs from "fs";

test("1:1 come back ordered by sortId", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);

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
	}, code);

	expect(result.length).toBe(2);
	expect(result[0].serverId).toBe("1");
	expect(result[1].serverId).toBe("2");
});

test("getMessagesBefore the end: MUC come back ordered by sortId, PM by timestamp", async ({
	page,
}) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);

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
	}, code);

	expect(result.length).toBe(3);
	expect(result[0].serverId).toBe("1");
	expect(result[1].serverId).toBe("2");
	expect(result[2].serverId).toBe("3");
});

test("getMessagesBefore some point: MUC come back ordered by sortId, PM by timestamp", async ({
	page,
}) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);

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
	}, code);

	expect(result.length).toBe(3);
	expect(result[0].serverId).toBe("1");
	expect(result[1].serverId).toBe("2");
	expect(result[2].serverId).toBe("3");
});

test("getMessagesBefore a PM", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);

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
	}, code);

	expect(result.length).toBe(2);
	expect(result[0].serverId).toBe("1");
	expect(result[1].serverId).toBe("2");
});

test("getMessagesAfter the start: MUC come back ordered by sortId, PM by timestamp", async ({
	page,
}) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);

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
	}, code);

	expect(result.length).toBe(3);
	expect(result[0].serverId).toBe("1");
	expect(result[1].serverId).toBe("2");
	expect(result[2].serverId).toBe("3");
});

test("getMessagesAfter some point: MUC come back ordered by sortId, PM by timestamp", async ({
	page,
}) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);

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
	}, code);

	expect(result.length).toBe(3);
	expect(result[0].serverId).toBe("2");
	expect(result[1].serverId).toBe("3");
	expect(result[2].serverId).toBe("4");
});

test("getMessagesAfter a PM", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);

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
	}, code);

	expect(result.length).toBe(1);
	expect(result[0].serverId).toBe("4");
});

test("storeChats and getChats", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);

		const chat = Object.create(borogove.DirectChat.prototype);
		chat.chatId = "hatter@example.com";
		chat.displayName = "The Mad Hatter";
		chat.trusted = true;
		chat.presence = new Map();
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
	}, code);

	expect(result.length).toBe(1);
	expect(result.chatId).toBe("hatter@example.com");
	expect(result.displayName).toBe("The Mad Hatter");
	expect(result.trusted).toBe(true);
	expect(result.klass).toBe("DirectChat");
	expect(result.channelSubject).toBe("Tea Time");
	expect(result.threadSubject).toBe("Introductions");
});

test("getMessage by serverId and localId", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);

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
	}, code);

	expect(result.byServerId).not.toBeNull();
	expect(result.byServerId.serverId).toBe("srv1");
	expect(result.byLocalId).not.toBeNull();
	expect(result.byLocalId.localId).toBe("loc1");
});

test("storeReaction", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);

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
		return {
			reactions: [...msg.reactions.entries()].map(([k, v]) => ({
				key: k,
				count: v.length,
			})),
		};
	}, code);

	expect(result.reactions.length).toBe(1);
	expect(result.reactions[0].key).toBe("👍");
	expect(result.reactions[0].count).toBe(1);
});

test("updateMessageStatus", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);

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
	}, code);

	expect(result.status).toBe(1);
	expect(result.statusText).toBe("Delivered");
});

test("searchMessages", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);

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
	}, code);

	expect(result.length).toBe(1);
	expect(result[0]).toBe("Hello world");
});

test("removeAccount and listAccounts", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);

		await persistence.storeLogin("alice@example.com", "client1", "Alice", null);
		await persistence.storeLogin("bob@example.com", "client2", "Bob", null);

		const accountsBefore = await persistence.listAccounts();
		await persistence.removeAccount("alice@example.com", true);
		const accountsAfter = await persistence.listAccounts();

		return { accountsBefore, accountsAfter };
	}, code);

	expect(result.accountsBefore).toContain("alice@example.com");
	expect(result.accountsBefore).toContain("bob@example.com");
	expect(result.accountsAfter).not.toContain("alice@example.com");
	expect(result.accountsAfter).toContain("bob@example.com");
});

test("getChatUnreadDetails", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);

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
	}, code);

	expect(result.unreadCount).toBe(1);
	expect(result.message.serverId).toBe("srv2");
});

test("media storage functions", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);

		const buffer = new Uint8Array([1, 2, 3]).buffer;
		await persistence.storeMedia("image/png", buffer);
		const sha256 = await crypto.subtle.digest("SHA-256", buffer);
		const hasBefore = await persistence.hasMedia("sha-256", sha256);
		await persistence.removeMedia("sha-256", sha256);
		const hasAfter = await persistence.hasMedia("sha-256", sha256);

		return { hasBefore, hasAfter };
	}, code);

	expect(result.hasBefore).toBe(true);
	expect(result.hasAfter).toBe(false);
});

test("hydrate message with incomplete replyToMessage keys", async ({
	page,
}) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);

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
		builder2.replyToMessage = parentMsg;
		const childMsg = builder2.build();

		await persistence.storeMessages("alice@example.com", [parentMsg, childMsg]);

		const db = await new Promise((resolve, reject) => {
			const req = indexedDB.open("snikket");
			req.onsuccess = () => resolve(req.result);
			req.onerror = () => reject(req.error);
		});
		const tx = db.transaction(["messages"], "readwrite");
		const store = tx.objectStore("messages");
		const key = ["alice@example.com", "child", "hatter@example.com", "loc2"];
		const rawChild = await new Promise((resolve) => {
			const req = store.get(key);
			req.onsuccess = () => resolve(req.result);
		});

		rawChild.replyToMessage = ["alice@example.com", "parent", "", ""];

		await new Promise((resolve) => {
			const req = store.put(rawChild);
			req.onsuccess = () => resolve();
		});
		await new Promise((resolve) => {
			tx.oncomplete = () => resolve();
		});

		const retrievedChild = await persistence.getMessage(
			"alice@example.com",
			"hatter@example.com",
			"child",
			"loc2",
		);
		return {
			hasReply: !!retrievedChild.replyToMessage,
			replyServerId: retrievedChild.replyToMessage
				? retrievedChild.replyToMessage.serverId
				: null,
		};
	}, code);

	expect(result.hasReply).toBe(true);
	expect(result.replyServerId).toBe("parent");
});

test("hydrate message with incomplete replyToMessage", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);

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
		const childMsg = builder2.build();

		await persistence.storeMessages("alice@example.com", [parentMsg]);
		const [childStored] = await persistence.storeMessages("alice@example.com", [
			childMsg,
		]);

		return childStored.replyToMessage.body().toPlainText();
	}, code);

	expect(result).toBe("Hello");
});

test("storeChats and getChats with status", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);

		const chat = Object.create(borogove.DirectChat.prototype);
		chat.chatId = "hatter@example.com";
		chat.displayName = "The Mad Hatter";
		chat.trusted = true;
		chat.presence = new Map();
		chat.threads = new Map();
		chat.status = new borogove.Status("🎩", "Time for tea!");

		await persistence.storeChats("alice@example.com", [chat]);
		const chats = await persistence.getChats("alice@example.com");
		return {
			length: chats.length,
			chatId: chats[0]?.chatId,
			statusEmoji: chats[0]?.status?.emoji,
			statusText: chats[0]?.status?.text,
		};
	}, code);

	expect(result.length).toBe(1);
	expect(result.chatId).toBe("hatter@example.com");
	expect(result.statusEmoji).toBe("🎩");
	expect(result.statusText).toBe("Time for tea!");
});

test("storeStreamManamagement and getStreamManagement", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);

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
	}, code);

	expect(result.smIsEq).toBe(0);
	expect(result.smIsArrayBuffer).toBe(true);
	expect(result.sortId).toBe("ZZ");
});

test("getMembers hydrates persisted member data", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);
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
	}, code);

	expect(result.id).toBe("room-members-1@example.com/occ-1");
	expect(result.displayName).toBe("Alice");
	expect(result.chatId).toBe("alice@example.com");
	expect(result.roleIds).toEqual(["admin"]);
	expect(result.presenceKeys).toEqual(["laptop"]);
	expect(result.showPresence).toBe(1);
});

test("storeMemberUpdates merges existing member data", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);
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
	}, code);

	expect(result.updatedRoleIds).toEqual(["urn:xmpp:hats:test"]);
	expect(result.updatedPresenceKeys).toEqual(["desk", "mobile"]);
	expect(result.updatedDisplayName).toBe("Alice Cooper");
});

test("storeMemberUpdates clears omitted full-list affiliations", async ({
	page,
}) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);
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
	}, code);

	expect(result).toEqual([]);
});

test("storeMemberUpdates matches existing member by true JID", async ({
	page,
}) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);
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
	}, code);

	expect(result).toBe("Alice Renamed");
});

test("clearMemberPresence only clears the targeted chat", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);
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
	}, code);

	expect(result.chat1PresenceKeys).toEqual([]);
	expect(result.chat2PresenceKeys).toEqual(["phone"]);
});

test("getMembers filters hidden rows for non-moderators", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);
		const chat = Object.create(borogove.Channel.prototype);
		chat.chatId = "room-members-5@example.com";
		chat.getDisplayName = () => "Tea Room";

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

		return normal.map((m) => m.displayName);
	}, code);

	expect(result).toEqual(["Zulu", "Alpha"]);
});

test("getMembers includes moderator-visible rows", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);
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
	}, code);

	expect(result).toEqual(["Zulu", "Alpha", "Banned"]);
});

test("getMemberDetails returns null for incomplete rows", async ({ page }) => {
	page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: "text/javascript" });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
		const persistence = await borogove.persistence.IDB("snikket", mediaStore);
		const chat = Object.create(borogove.Channel.prototype);
		chat.chatId = "room-members-7@example.com";
		chat.getDisplayName = () => "Tea Room";

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

		const tx = indexedDB.open("snikket");
		const db = await new Promise((resolve, reject) => {
			tx.onsuccess = () => resolve(tx.result);
			tx.onerror = () => reject(tx.error);
		});
		const write = db.transaction(["members"], "readwrite");
		write.objectStore("members").put({
			account: "alice@example.com",
			chatId: chat.chatId,
			id: "room-members-7@example.com/incomplete",
			displayName: "",
			photoUri: null,
			isSelf: 0,
			chat: "",
			roles: [],
			presence: new Map(),
			jid: "",
		});
		await new Promise((resolve, reject) => {
			write.oncomplete = () => resolve(null);
			write.onerror = () => reject(write.error);
		});

		const details = await persistence.getMemberDetails(
			"alice@example.com",
			chat,
			[
				"room-members-7@example.com/admin",
				"room-members-7@example.com/incomplete",
			],
		);
		return details.map((m) => (m ? m.displayName : null));
	}, code);

	expect(result).toEqual(["Alpha", null]);
});
