import { test, expect } from "@playwright/test";
import fs from "fs";

test("1:1 come back ordered by sortId", async ({ page }) => {
	page.route("https://localhost/", route => route.fulfill({ body: "<html></html>" }));
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: 'text/javascript' });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = borogove.persistence.MediaStoreCache("snikket");
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

		return await persistence.getMessagesBefore("alice@example.com", "hatter@example.com");
	}, code);

	expect(result.length).toBe(2);
	expect(result[0].serverId).toBe("1");
	expect(result[1].serverId).toBe("2");
});

test("getMessagesBefore the end: MUC come back ordered by sortId, PM by timestamp", async ({ page }) => {
	page.route("https://localhost/", route => route.fulfill({ body: "<html></html>" }));
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: 'text/javascript' });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = borogove.persistence.MediaStoreCache("snikket");
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

		return await persistence.getMessagesBefore("alice@example.com", "teaparty@example.com");
	}, code);

	expect(result.length).toBe(3);
	expect(result[0].serverId).toBe("1");
	expect(result[1].serverId).toBe("2");
	expect(result[2].serverId).toBe("3");
});

test("getMessagesBefore some point: MUC come back ordered by sortId, PM by timestamp", async ({ page }) => {
	page.route("https://localhost/", route => route.fulfill({ body: "<html></html>" }));
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: 'text/javascript' });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = borogove.persistence.MediaStoreCache("snikket");
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

		return await persistence.getMessagesBefore("alice@example.com", "teaparty@example.com", builder4.build());
	}, code);

	expect(result.length).toBe(3);
	expect(result[0].serverId).toBe("1");
	expect(result[1].serverId).toBe("2");
	expect(result[2].serverId).toBe("3");
});

test("getMessagesBefore a PM", async ({ page }) => {
	page.route("https://localhost/", route => route.fulfill({ body: "<html></html>" }));
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: 'text/javascript' });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = borogove.persistence.MediaStoreCache("snikket");
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

		return await persistence.getMessagesBefore("alice@example.com", "teaparty@example.com", builder3.build());
	}, code);

	expect(result.length).toBe(2);
	expect(result[0].serverId).toBe("1");
	expect(result[1].serverId).toBe("2");
});

test("getMessagesAfter the start: MUC come back ordered by sortId, PM by timestamp", async ({ page }) => {
	page.route("https://localhost/", route => route.fulfill({ body: "<html></html>" }));
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: 'text/javascript' });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = borogove.persistence.MediaStoreCache("snikket");
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

		return await persistence.getMessagesAfter("alice@example.com", "teaparty@example.com");
	}, code);

	expect(result.length).toBe(3);
	expect(result[0].serverId).toBe("1");
	expect(result[1].serverId).toBe("2");
	expect(result[2].serverId).toBe("3");
});

test("getMessagesAfter some point: MUC come back ordered by sortId, PM by timestamp", async ({ page }) => {
	page.route("https://localhost/", route => route.fulfill({ body: "<html></html>" }));
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: 'text/javascript' });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = borogove.persistence.MediaStoreCache("snikket");
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

		return await persistence.getMessagesAfter("alice@example.com", "teaparty@example.com", builder.build());
	}, code);

	expect(result.length).toBe(3);
	expect(result[0].serverId).toBe("2");
	expect(result[1].serverId).toBe("3");
	expect(result[2].serverId).toBe("4");
});

test("getMessagesAfter a PM", async ({ page }) => {
	page.route("https://localhost/", route => route.fulfill({ body: "<html></html>" }));
	const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
	await page.goto("https://localhost/");
	const result = await page.evaluate(async (code) => {
		const blob = new Blob([code], { type: 'text/javascript' });
		const borogove = await import(URL.createObjectURL(blob));

		const mediaStore = borogove.persistence.MediaStoreCache("snikket");
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

		return await persistence.getMessagesAfter("alice@example.com", "teaparty@example.com", builder3.build());
	}, code);

	expect(result.length).toBe(1);
	expect(result[0].serverId).toBe("4");
});
