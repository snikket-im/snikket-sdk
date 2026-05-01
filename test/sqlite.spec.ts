import { test, expect } from "@playwright/test";
import fs from "fs";

test.describe("not webkit", () => {
	test.skip(
		({ browserName }) => browserName === "webkit",
		"Skip on webkit because the version in playwright lacks OPFS",
	);

	test("1:1 come back ordered by sortId", async ({ page }) => {
		page.route("https://localhost/", (route) =>
			route.fulfill({
				headers: {
					"Cross-Origin-Opener-Policy": "same-origin",
					"Cross-Origin-Embedder-Policy": "same-origin",
					"Cross-Origin-Resource-Policy": "same-origin",
				},
				body: "<html></html>",
			}),
		);
		const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
		const sqlite = fs.readFileSync("playwright/.cache/sqlite-wasm.js", "utf8");
		const worker1 = fs.readFileSync(
			"playwright/.cache/sqlite-worker1.js",
			"utf8",
		);
		await page.goto("https://localhost/");
		const result = await page.evaluate(
			async ([code, sqliteCode, worker1Code]) => {
				const blob = new Blob([code], { type: "text/javascript" });
				const borogove = await import(URL.createObjectURL(blob));

				const sqliteBlob = new Blob([sqliteCode], { type: "text/javascript" });
				const sqlite = await import(URL.createObjectURL(sqliteBlob));

				const worker1Blob = new Blob([worker1Code], {
					type: "text/javascript",
				});
				window.sqliteWorker1Url = new URL(URL.createObjectURL(worker1Blob));

				const mediaStore =
					await borogove.persistence.MediaStoreCache("snikket");
				const persistence = new sqlite.borogove_persistence_Sqlite(
					"snikket",
					mediaStore,
				);

				const builder = new borogove.ChatMessageBuilder({
					serverId: "1",
					serverIdBy: "alice@example.com",
					senderId: "hatter@example.com",
					direction: 0,
				});
				builder.sortId = "a0";
				builder.to = borogove.JID.parse("alice@example.com");
				builder.from = borogove.JID.parse("hatter@example.com");
				builder.recipients = [builder.to];
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
				builder2.recipients = [builder2.to];
				builder2.replyTo = [builder2.from];

				try {
					await persistence.storeMessages("alice@example.com", [
						builder2.build(),
						builder.build(),
					]);

					return await persistence.getMessagesBefore(
						"alice@example.com",
						"hatter@example.com",
					);
				} catch (e) {
					console.error(e, e.result);
					throw e.result ? JSON.stringify(e.result) : e.message;
				}
			},
			[code, sqlite, worker1],
		);

		expect(result.length).toBe(2);
		expect(result[0].serverId).toBe("1");
		expect(result[1].serverId).toBe("2");
	});

	test("getMessagesBefore the end: MUC come back ordered by sortId, PM by timestamp", async ({
		page,
	}) => {
		page.route("https://localhost/", (route) =>
			route.fulfill({
				body: "<html></html>",
				headers: {
					"Cross-Origin-Opener-Policy": "same-origin",
					"Cross-Origin-Embedder-Policy": "same-origin",
					"Cross-Origin-Resource-Policy": "same-origin",
				},
			}),
		);
		const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
		const sqlite = fs.readFileSync("playwright/.cache/sqlite-wasm.js", "utf8");
		const worker1 = fs.readFileSync(
			"playwright/.cache/sqlite-worker1.js",
			"utf8",
		);
		await page.goto("https://localhost/");
		const result = await page.evaluate(
			async ([code, sqliteCode, worker1Code]) => {
				const borogove = await import(
					URL.createObjectURL(new Blob([code], { type: "text/javascript" }))
				);
				const sqlite = await import(
					URL.createObjectURL(
						new Blob([sqliteCode], { type: "text/javascript" }),
					)
				);
				window.sqliteWorker1Url = new URL(
					URL.createObjectURL(
						new Blob([worker1Code], { type: "text/javascript" }),
					),
				);
				const persistence = new sqlite.borogove_persistence_Sqlite(
					"snikket",
					await borogove.persistence.MediaStoreCache("snikket"),
				);

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
				builder2.replyTo = [builder2.from.asBare()];

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
				builder3.replyTo = [builder3.from.asBare()];

				try {
					await persistence.storeMessages("alice@example.com", [
						builder2.build(),
						builder3.build(),
						builder.build(),
					]);
					return await persistence.getMessagesBefore(
						"alice@example.com",
						"teaparty@example.com",
					);
				} catch (e) {
					console.error(e, e.result);
					throw e.result ? JSON.stringify(e.result) : e.message;
				}
			},
			[code, sqlite, worker1],
		);

		expect(result.length).toBe(3);
		expect(result[0].serverId).toBe("1");
		expect(result[1].serverId).toBe("2");
		expect(result[2].serverId).toBe("3");
	});

	test("getMessagesBefore some point: MUC come back ordered by sortId, PM by timestamp", async ({
		page,
	}) => {
		page.route("https://localhost/", (route) =>
			route.fulfill({
				body: "<html></html>",
				headers: {
					"Cross-Origin-Opener-Policy": "same-origin",
					"Cross-Origin-Embedder-Policy": "same-origin",
					"Cross-Origin-Resource-Policy": "same-origin",
				},
			}),
		);
		const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
		const sqlite = fs.readFileSync("playwright/.cache/sqlite-wasm.js", "utf8");
		const worker1 = fs.readFileSync(
			"playwright/.cache/sqlite-worker1.js",
			"utf8",
		);
		await page.goto("https://localhost/");
		const result = await page.evaluate(
			async ([code, sqliteCode, worker1Code]) => {
				const borogove = await import(
					URL.createObjectURL(new Blob([code], { type: "text/javascript" }))
				);
				const sqlite = await import(
					URL.createObjectURL(
						new Blob([sqliteCode], { type: "text/javascript" }),
					)
				);
				window.sqliteWorker1Url = new URL(
					URL.createObjectURL(
						new Blob([worker1Code], { type: "text/javascript" }),
					),
				);
				const persistence = new sqlite.borogove_persistence_Sqlite(
					"snikket",
					await borogove.persistence.MediaStoreCache("snikket"),
				);

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
				builder2.replyTo = [builder2.from.asBare()];

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
				builder3.replyTo = [builder3.from.asBare()];

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
				builder4.replyTo = [builder4.from.asBare()];

				try {
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
				} catch (e) {
					console.error(e, e.result);
					throw e.result ? JSON.stringify(e.result) : e.message;
				}
			},
			[code, sqlite, worker1],
		);

		expect(result.length).toBe(3);
		expect(result[0].serverId).toBe("1");
		expect(result[1].serverId).toBe("2");
		expect(result[2].serverId).toBe("3");
	});

	test("getMessagesBefore a PM", async ({ page }) => {
		page.route("https://localhost/", (route) =>
			route.fulfill({
				body: "<html></html>",
				headers: {
					"Cross-Origin-Opener-Policy": "same-origin",
					"Cross-Origin-Embedder-Policy": "same-origin",
					"Cross-Origin-Resource-Policy": "same-origin",
				},
			}),
		);
		const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
		const sqlite = fs.readFileSync("playwright/.cache/sqlite-wasm.js", "utf8");
		const worker1 = fs.readFileSync(
			"playwright/.cache/sqlite-worker1.js",
			"utf8",
		);
		await page.goto("https://localhost/");
		const result = await page.evaluate(
			async ([code, sqliteCode, worker1Code]) => {
				const borogove = await import(
					URL.createObjectURL(new Blob([code], { type: "text/javascript" }))
				);
				const sqlite = await import(
					URL.createObjectURL(
						new Blob([sqliteCode], { type: "text/javascript" }),
					)
				);
				window.sqliteWorker1Url = new URL(
					URL.createObjectURL(
						new Blob([worker1Code], { type: "text/javascript" }),
					),
				);
				const persistence = new sqlite.borogove_persistence_Sqlite(
					"snikket",
					await borogove.persistence.MediaStoreCache("snikket"),
				);

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
				builder2.replyTo = [builder2.from.asBare()];

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
				builder3.replyTo = [builder3.from.asBare()];

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
				builder4.replyTo = [builder4.from.asBare()];

				try {
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
				} catch (e) {
					console.error(e, e.result);
					throw e.result ? JSON.stringify(e.result) : e.message;
				}
			},
			[code, sqlite, worker1],
		);

		expect(result.length).toBe(2);
		expect(result[0].serverId).toBe("1");
		expect(result[1].serverId).toBe("2");
	});

	test("getMessagesAfter the start: MUC come back ordered by sortId, PM by timestamp", async ({
		page,
	}) => {
		page.route("https://localhost/", (route) =>
			route.fulfill({
				body: "<html></html>",
				headers: {
					"Cross-Origin-Opener-Policy": "same-origin",
					"Cross-Origin-Embedder-Policy": "same-origin",
					"Cross-Origin-Resource-Policy": "same-origin",
				},
			}),
		);
		const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
		const sqlite = fs.readFileSync("playwright/.cache/sqlite-wasm.js", "utf8");
		const worker1 = fs.readFileSync(
			"playwright/.cache/sqlite-worker1.js",
			"utf8",
		);
		await page.goto("https://localhost/");
		const result = await page.evaluate(
			async ([code, sqliteCode, worker1Code]) => {
				const borogove = await import(
					URL.createObjectURL(new Blob([code], { type: "text/javascript" }))
				);
				const sqlite = await import(
					URL.createObjectURL(
						new Blob([sqliteCode], { type: "text/javascript" }),
					)
				);
				window.sqliteWorker1Url = new URL(
					URL.createObjectURL(
						new Blob([worker1Code], { type: "text/javascript" }),
					),
				);
				const persistence = new sqlite.borogove_persistence_Sqlite(
					"snikket",
					await borogove.persistence.MediaStoreCache("snikket"),
				);

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
				builder2.replyTo = [builder2.from.asBare()];

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
				builder3.replyTo = [builder3.from.asBare()];

				try {
					await persistence.storeMessages("alice@example.com", [
						builder2.build(),
						builder3.build(),
						builder.build(),
					]);
					return await persistence.getMessagesAfter(
						"alice@example.com",
						"teaparty@example.com",
					);
				} catch (e) {
					console.error(e, e.result);
					throw e.result ? JSON.stringify(e.result) : e.message;
				}
			},
			[code, sqlite, worker1],
		);

		expect(result.length).toBe(3);
		expect(result[0].serverId).toBe("1");
		expect(result[1].serverId).toBe("2");
		expect(result[2].serverId).toBe("3");
	});

	test("getMessagesAfter some point: MUC come back ordered by sortId, PM by timestamp", async ({
		page,
	}) => {
		page.route("https://localhost/", (route) =>
			route.fulfill({
				body: "<html></html>",
				headers: {
					"Cross-Origin-Opener-Policy": "same-origin",
					"Cross-Origin-Embedder-Policy": "same-origin",
					"Cross-Origin-Resource-Policy": "same-origin",
				},
			}),
		);
		const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
		const sqlite = fs.readFileSync("playwright/.cache/sqlite-wasm.js", "utf8");
		const worker1 = fs.readFileSync(
			"playwright/.cache/sqlite-worker1.js",
			"utf8",
		);
		await page.goto("https://localhost/");
		const result = await page.evaluate(
			async ([code, sqliteCode, worker1Code]) => {
				const borogove = await import(
					URL.createObjectURL(new Blob([code], { type: "text/javascript" }))
				);
				const sqlite = await import(
					URL.createObjectURL(
						new Blob([sqliteCode], { type: "text/javascript" }),
					)
				);
				window.sqliteWorker1Url = new URL(
					URL.createObjectURL(
						new Blob([worker1Code], { type: "text/javascript" }),
					),
				);
				const persistence = new sqlite.borogove_persistence_Sqlite(
					"snikket",
					await borogove.persistence.MediaStoreCache("snikket"),
				);

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
				builder2.replyTo = [builder2.from.asBare()];

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
				builder3.replyTo = [builder3.from.asBare()];

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
				builder4.replyTo = [builder4.from.asBare()];

				try {
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
				} catch (e) {
					console.error(e, e.result);
					throw e.result ? JSON.stringify(e.result) : e.message;
				}
			},
			[code, sqlite, worker1],
		);

		expect(result.length).toBe(3);
		expect(result[0].serverId).toBe("2");
		expect(result[1].serverId).toBe("3");
		expect(result[2].serverId).toBe("4");
	});

	test("getMessagesAfter a PM", async ({ page }) => {
		page.route("https://localhost/", (route) =>
			route.fulfill({
				body: "<html></html>",
				headers: {
					"Cross-Origin-Opener-Policy": "same-origin",
					"Cross-Origin-Embedder-Policy": "same-origin",
					"Cross-Origin-Resource-Policy": "same-origin",
				},
			}),
		);
		const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
		const sqlite = fs.readFileSync("playwright/.cache/sqlite-wasm.js", "utf8");
		const worker1 = fs.readFileSync(
			"playwright/.cache/sqlite-worker1.js",
			"utf8",
		);
		await page.goto("https://localhost/");
		const result = await page.evaluate(
			async ([code, sqliteCode, worker1Code]) => {
				const borogove = await import(
					URL.createObjectURL(new Blob([code], { type: "text/javascript" }))
				);
				const sqlite = await import(
					URL.createObjectURL(
						new Blob([sqliteCode], { type: "text/javascript" }),
					)
				);
				window.sqliteWorker1Url = new URL(
					URL.createObjectURL(
						new Blob([worker1Code], { type: "text/javascript" }),
					),
				);
				const persistence = new sqlite.borogove_persistence_Sqlite(
					"snikket",
					await borogove.persistence.MediaStoreCache("snikket"),
				);

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
				builder2.replyTo = [builder2.from.asBare()];

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
				builder3.replyTo = [builder3.from.asBare()];

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
				builder4.replyTo = [builder4.from.asBare()];

				try {
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
				} catch (e) {
					console.error(e, e.result);
					throw e.result ? JSON.stringify(e.result) : e.message;
				}
			},
			[code, sqlite, worker1],
		);

		expect(result.length).toBe(1);
		expect(result[0].serverId).toBe("4");
	});

	test("storeChats and getChats", async ({ page }) => {
		page.route("https://localhost/", (route) =>
			route.fulfill({
				body: "<html></html>",
				headers: {
					"Cross-Origin-Opener-Policy": "same-origin",
					"Cross-Origin-Embedder-Policy": "same-origin",
					"Cross-Origin-Resource-Policy": "same-origin",
				},
			}),
		);
		const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
		const sqlite = fs.readFileSync("playwright/.cache/sqlite-wasm.js", "utf8");
		const worker1 = fs.readFileSync(
			"playwright/.cache/sqlite-worker1.js",
			"utf8",
		);
		await page.goto("https://localhost/");
		const result = await page.evaluate(
			async ([code, sqliteCode, worker1Code]) => {
				const borogove = await import(
					URL.createObjectURL(new Blob([code], { type: "text/javascript" }))
				);
				const sqlite = await import(
					URL.createObjectURL(
						new Blob([sqliteCode], { type: "text/javascript" }),
					)
				);
				window.sqliteWorker1Url = new URL(
					URL.createObjectURL(
						new Blob([worker1Code], { type: "text/javascript" }),
					),
				);
				const persistence = new sqlite.borogove_persistence_Sqlite(
					"snikket",
					await borogove.persistence.MediaStoreCache("snikket"),
				);

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

				try {
					await persistence.storeChats("alice@example.com", [chat]);
					await new Promise((resolve) => setTimeout(resolve, 200));
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
				} catch (e) {
					console.error(e, e.result);
					throw e.result ? JSON.stringify(e.result) : e.message;
				}
			},
			[code, sqlite, worker1],
		);

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
			route.fulfill({
				body: "<html></html>",
				headers: {
					"Cross-Origin-Opener-Policy": "same-origin",
					"Cross-Origin-Embedder-Policy": "same-origin",
					"Cross-Origin-Resource-Policy": "same-origin",
				},
			}),
		);
		const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
		const sqlite = fs.readFileSync("playwright/.cache/sqlite-wasm.js", "utf8");
		const worker1 = fs.readFileSync(
			"playwright/.cache/sqlite-worker1.js",
			"utf8",
		);
		await page.goto("https://localhost/");
		const result = await page.evaluate(
			async ([code, sqliteCode, worker1Code]) => {
				const borogove = await import(
					URL.createObjectURL(new Blob([code], { type: "text/javascript" }))
				);
				const sqlite = await import(
					URL.createObjectURL(
						new Blob([sqliteCode], { type: "text/javascript" }),
					)
				);
				window.sqliteWorker1Url = new URL(
					URL.createObjectURL(
						new Blob([worker1Code], { type: "text/javascript" }),
					),
				);
				const persistence = new sqlite.borogove_persistence_Sqlite(
					"snikket",
					await borogove.persistence.MediaStoreCache("snikket"),
				);

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

				try {
					await persistence.storeMessages("alice@example.com", [
						builder.build(),
					]);

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
							? { serverId: byServerId.serverId, localId: byLocalId.localId }
							: null,
						byLocalId: byLocalId
							? { serverId: byLocalId.serverId, localId: byLocalId.localId }
							: null,
					};
				} catch (e) {
					console.error(e, e.result);
					throw e.result ? JSON.stringify(e.result) : e.message;
				}
			},
			[code, sqlite, worker1],
		);

		expect(result.byServerId).not.toBeNull();
		expect(result.byServerId.serverId).toBe("srv1");
		expect(result.byLocalId).not.toBeNull();
		expect(result.byLocalId.localId).toBe("loc1");
	});

	test("storeReaction", async ({ page }) => {
		page.route("https://localhost/", (route) =>
			route.fulfill({
				body: "<html></html>",
				headers: {
					"Cross-Origin-Opener-Policy": "same-origin",
					"Cross-Origin-Embedder-Policy": "same-origin",
					"Cross-Origin-Resource-Policy": "same-origin",
				},
			}),
		);
		const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
		const sqlite = fs.readFileSync("playwright/.cache/sqlite-wasm.js", "utf8");
		const worker1 = fs.readFileSync(
			"playwright/.cache/sqlite-worker1.js",
			"utf8",
		);
		await page.goto("https://localhost/");
		const result = await page.evaluate(
			async ([code, sqliteCode, worker1Code]) => {
				const borogove = await import(
					URL.createObjectURL(new Blob([code], { type: "text/javascript" }))
				);
				const sqlite = await import(
					URL.createObjectURL(
						new Blob([sqliteCode], { type: "text/javascript" }),
					)
				);
				window.sqliteWorker1Url = new URL(
					URL.createObjectURL(
						new Blob([worker1Code], { type: "text/javascript" }),
					),
				);
				const persistence = new sqlite.borogove_persistence_Sqlite(
					"snikket",
					await borogove.persistence.MediaStoreCache("snikket"),
				);

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

				try {
					await persistence.storeMessages("alice@example.com", [
						builder.build(),
					]);

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
				} catch (e) {
					console.error(e, e.result);
					throw e.result ? JSON.stringify(e.result) : e.message;
				}
			},
			[code, sqlite, worker1],
		);

		expect(result.reactions.length).toBe(1);
		expect(result.reactions[0].key).toBe("👍");
		expect(result.reactions[0].count).toBe(1);
	});

	test("updateMessageStatus", async ({ page }) => {
		page.route("https://localhost/", (route) =>
			route.fulfill({
				body: "<html></html>",
				headers: {
					"Cross-Origin-Opener-Policy": "same-origin",
					"Cross-Origin-Embedder-Policy": "same-origin",
					"Cross-Origin-Resource-Policy": "same-origin",
				},
			}),
		);
		const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
		const sqlite = fs.readFileSync("playwright/.cache/sqlite-wasm.js", "utf8");
		const worker1 = fs.readFileSync(
			"playwright/.cache/sqlite-worker1.js",
			"utf8",
		);
		await page.goto("https://localhost/");
		const result = await page.evaluate(
			async ([code, sqliteCode, worker1Code]) => {
				const borogove = await import(
					URL.createObjectURL(new Blob([code], { type: "text/javascript" }))
				);
				const sqlite = await import(
					URL.createObjectURL(
						new Blob([sqliteCode], { type: "text/javascript" }),
					)
				);
				window.sqliteWorker1Url = new URL(
					URL.createObjectURL(
						new Blob([worker1Code], { type: "text/javascript" }),
					),
				);
				const persistence = new sqlite.borogove_persistence_Sqlite(
					"snikket",
					await borogove.persistence.MediaStoreCache("snikket"),
				);

				const builder = new borogove.ChatMessageBuilder({
					localId: "loc1",
					senderId: "alice@example.com",
					direction: 1,
				});
				builder.sortId = "a0";
				builder.to = borogove.JID.parse("hatter@example.com");
				builder.from = borogove.JID.parse("alice@example.com");
				builder.recipients = [builder.to];
				builder.replyTo = [builder.from];

				try {
					await persistence.storeMessages("alice@example.com", [
						builder.build(),
					]);

					const updated = await persistence.updateMessageStatus(
						"alice@example.com",
						"loc1",
						1,
						"Delivered",
					);
					return { status: updated.status, statusText: updated.statusText };
				} catch (e) {
					console.error(e, e.result);
					throw e.result ? JSON.stringify(e.result) : e.message;
				}
			},
			[code, sqlite, worker1],
		);

		expect(result.status).toBe(1);
		expect(result.statusText).toBe("Delivered");
	});

	test("searchMessages", async ({ page }) => {
		page.route("https://localhost/", (route) =>
			route.fulfill({
				body: "<html></html>",
				headers: {
					"Cross-Origin-Opener-Policy": "same-origin",
					"Cross-Origin-Embedder-Policy": "same-origin",
					"Cross-Origin-Resource-Policy": "same-origin",
				},
			}),
		);
		const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
		const sqlite = fs.readFileSync("playwright/.cache/sqlite-wasm.js", "utf8");
		const worker1 = fs.readFileSync(
			"playwright/.cache/sqlite-worker1.js",
			"utf8",
		);
		await page.goto("https://localhost/");
		const result = await page.evaluate(
			async ([code, sqliteCode, worker1Code]) => {
				const borogove = await import(
					URL.createObjectURL(new Blob([code], { type: "text/javascript" }))
				);
				const sqlite = await import(
					URL.createObjectURL(
						new Blob([sqliteCode], { type: "text/javascript" }),
					)
				);
				window.sqliteWorker1Url = new URL(
					URL.createObjectURL(
						new Blob([worker1Code], { type: "text/javascript" }),
					),
				);
				const persistence = new sqlite.borogove_persistence_Sqlite(
					"snikket",
					await borogove.persistence.MediaStoreCache("snikket"),
				);

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

				try {
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
				} catch (e) {
					console.error(e, e.result);
					throw e.result ? JSON.stringify(e.result) : e.message;
				}
			},
			[code, sqlite, worker1],
		);

		expect(result.length).toBe(1);
		expect(result[0]).toBe("Hello world");
	});

	test("removeAccount and listAccounts", async ({ page }) => {
		page.route("https://localhost/", (route) =>
			route.fulfill({
				body: "<html></html>",
				headers: {
					"Cross-Origin-Opener-Policy": "same-origin",
					"Cross-Origin-Embedder-Policy": "same-origin",
					"Cross-Origin-Resource-Policy": "same-origin",
				},
			}),
		);
		const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
		const sqlite = fs.readFileSync("playwright/.cache/sqlite-wasm.js", "utf8");
		const worker1 = fs.readFileSync(
			"playwright/.cache/sqlite-worker1.js",
			"utf8",
		);
		await page.goto("https://localhost/");
		const result = await page.evaluate(
			async ([code, sqliteCode, worker1Code]) => {
				const borogove = await import(
					URL.createObjectURL(new Blob([code], { type: "text/javascript" }))
				);
				const sqlite = await import(
					URL.createObjectURL(
						new Blob([sqliteCode], { type: "text/javascript" }),
					)
				);
				window.sqliteWorker1Url = new URL(
					URL.createObjectURL(
						new Blob([worker1Code], { type: "text/javascript" }),
					),
				);
				const persistence = new sqlite.borogove_persistence_Sqlite(
					"snikket",
					await borogove.persistence.MediaStoreCache("snikket"),
				);

				try {
					await persistence.storeLogin(
						"alice@example.com",
						"client1",
						"Alice",
						null,
					);
					await persistence.storeLogin(
						"bob@example.com",
						"client2",
						"Bob",
						null,
					);
					const accountsBefore = await persistence.listAccounts();
					await persistence.removeAccount("alice@example.com", true);
					const accountsAfter = await persistence.listAccounts();
					return { accountsBefore, accountsAfter };
				} catch (e) {
					console.error(e, e.result);
					throw e.result ? JSON.stringify(e.result) : e.message;
				}
			},
			[code, sqlite, worker1],
		);

		expect(result.accountsBefore).toContain("alice@example.com");
		expect(result.accountsBefore).toContain("bob@example.com");
		expect(result.accountsAfter).not.toContain("alice@example.com");
		expect(result.accountsAfter).toContain("bob@example.com");
	});

	test("getChatUnreadDetails", async ({ page }) => {
		page.route("https://localhost/", (route) =>
			route.fulfill({
				body: "<html></html>",
				headers: {
					"Cross-Origin-Opener-Policy": "same-origin",
					"Cross-Origin-Embedder-Policy": "same-origin",
					"Cross-Origin-Resource-Policy": "same-origin",
				},
			}),
		);
		const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
		const sqlite = fs.readFileSync("playwright/.cache/sqlite-wasm.js", "utf8");
		const worker1 = fs.readFileSync(
			"playwright/.cache/sqlite-worker1.js",
			"utf8",
		);
		await page.goto("https://localhost/");
		const result = await page.evaluate(
			async ([code, sqliteCode, worker1Code]) => {
				const borogove = await import(
					URL.createObjectURL(new Blob([code], { type: "text/javascript" }))
				);
				const sqlite = await import(
					URL.createObjectURL(
						new Blob([sqliteCode], { type: "text/javascript" }),
					)
				);
				window.sqliteWorker1Url = new URL(
					URL.createObjectURL(
						new Blob([worker1Code], { type: "text/javascript" }),
					),
				);
				const persistence = new sqlite.borogove_persistence_Sqlite(
					"snikket",
					await borogove.persistence.MediaStoreCache("snikket"),
				);

				const chat = Object.create(borogove.DirectChat.prototype);
				chat.constructor = borogove.DirectChat;
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

				try {
					await persistence.storeMessages("alice@example.com", [
						builder.build(),
						builder2.build(),
					]);
					return await persistence.getChatUnreadDetails(
						"alice@example.com",
						chat,
					);
				} catch (e) {
					console.error(e, e.result);
					throw e.result ? JSON.stringify(e.result) : e.message;
				}
			},
			[code, sqlite, worker1],
		);

		expect(result.unreadCount).toBe(1);
		expect(result.message.serverId).toBe("srv2");
	});

	test("media storage functions", async ({ page }) => {
		page.route("https://localhost/", (route) =>
			route.fulfill({
				body: "<html></html>",
				headers: {
					"Cross-Origin-Opener-Policy": "same-origin",
					"Cross-Origin-Embedder-Policy": "same-origin",
					"Cross-Origin-Resource-Policy": "same-origin",
				},
			}),
		);
		const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
		const sqlite = fs.readFileSync("playwright/.cache/sqlite-wasm.js", "utf8");
		const worker1 = fs.readFileSync(
			"playwright/.cache/sqlite-worker1.js",
			"utf8",
		);
		await page.goto("https://localhost/");
		const result = await page.evaluate(
			async ([code, sqliteCode, worker1Code]) => {
				const borogove = await import(
					URL.createObjectURL(new Blob([code], { type: "text/javascript" }))
				);
				const sqlite = await import(
					URL.createObjectURL(
						new Blob([sqliteCode], { type: "text/javascript" }),
					)
				);
				window.sqliteWorker1Url = new URL(
					URL.createObjectURL(
						new Blob([worker1Code], { type: "text/javascript" }),
					),
				);
				const persistence = new sqlite.borogove_persistence_Sqlite(
					"snikket",
					await borogove.persistence.MediaStoreCache("snikket"),
				);

				try {
					const buffer = new Uint8Array([1, 2, 3]).buffer;
					await persistence.storeMedia("image/png", buffer);
					const sha256 = await crypto.subtle.digest("SHA-256", buffer);
					const hasBefore = await persistence.hasMedia("sha-256", sha256);
					await persistence.removeMedia("sha-256", sha256);
					const hasAfter = await persistence.hasMedia("sha-256", sha256);
					return { hasBefore, hasAfter };
				} catch (e) {
					console.error(e, e.result);
					throw e.result ? JSON.stringify(e.result) : e.message;
				}
			},
			[code, sqlite, worker1],
		);

		expect(result.hasBefore).toBe(true);
		expect(result.hasAfter).toBe(false);
	});

	test("hydrate message with incomplete replyToMessage", async ({ page }) => {
		page.route("https://localhost/", (route) =>
			route.fulfill({
				body: "<html></html>",
				headers: {
					"Cross-Origin-Opener-Policy": "same-origin",
					"Cross-Origin-Embedder-Policy": "same-origin",
					"Cross-Origin-Resource-Policy": "same-origin",
				},
			}),
		);
		const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
		const sqlite = fs.readFileSync("playwright/.cache/sqlite-wasm.js", "utf8");
		const worker1 = fs.readFileSync(
			"playwright/.cache/sqlite-worker1.js",
			"utf8",
		);
		await page.goto("https://localhost/");
		const result = await page.evaluate(
			async ([code, sqliteCode, worker1Code]) => {
				const borogove = await import(
					URL.createObjectURL(new Blob([code], { type: "text/javascript" }))
				);
				const sqlite = await import(
					URL.createObjectURL(
						new Blob([sqliteCode], { type: "text/javascript" }),
					)
				);
				window.sqliteWorker1Url = new URL(
					URL.createObjectURL(
						new Blob([worker1Code], { type: "text/javascript" }),
					),
				);
				const persistence = new sqlite.borogove_persistence_Sqlite(
					"snikket",
					await borogove.persistence.MediaStoreCache("snikket"),
				);

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
				const [childStored] = await persistence.storeMessages(
					"alice@example.com",
					[childMsg],
				);

				return childStored.replyToMessage.body().toPlainText();
			},
			[code, sqlite, worker1],
		);

		expect(result).toBe("Hello");
	});

	test("storeChats and getChats with status", async ({ page }) => {
		page.route("https://localhost/", (route) =>
			route.fulfill({
				body: "<html></html>",
				headers: {
					"Cross-Origin-Opener-Policy": "same-origin",
					"Cross-Origin-Embedder-Policy": "same-origin",
					"Cross-Origin-Resource-Policy": "same-origin",
				},
			}),
		);
		const code = fs.readFileSync("playwright/.cache/borogove.js", "utf8");
		const sqlite = fs.readFileSync("playwright/.cache/sqlite-wasm.js", "utf8");
		const worker1 = fs.readFileSync(
			"playwright/.cache/sqlite-worker1.js",
			"utf8",
		);
		await page.goto("https://localhost/");
		const result = await page.evaluate(
			async ([code, sqliteCode, worker1Code]) => {
				const borogove = await import(
					URL.createObjectURL(new Blob([code], { type: "text/javascript" }))
				);
				const sqlite = await import(
					URL.createObjectURL(
						new Blob([sqliteCode], { type: "text/javascript" }),
					)
				);
				window.sqliteWorker1Url = new URL(
					URL.createObjectURL(
						new Blob([worker1Code], { type: "text/javascript" }),
					),
				);
				const persistence = new sqlite.borogove_persistence_Sqlite(
					"snikket",
					await borogove.persistence.MediaStoreCache("snikket"),
				);

				const chat = new borogove.DirectChat(
					null,
					null,
					persistence,
					"hatter@example.com",
				);
				chat.displayName = "The Mad Hatter";
				chat.trusted = true;
				chat.status = new borogove.Status("🎩", "Time for tea!");

				try {
					await persistence.storeChats("alice@example.com", [chat]);
					await new Promise((resolve) => setTimeout(resolve, 200));
					const chats = await persistence.getChats("alice@example.com");
					return {
						length: chats.length,
						chatId: chats[0]?.chatId,
						statusEmoji: chats[0]?.status?.emoji,
						statusText: chats[0]?.status?.text,
					};
				} catch (e) {
					console.error(e, e.result);
					throw e.result ? JSON.stringify(e.result) : e.message;
				}
			},
			[code, sqlite, worker1],
		);

		expect(result.length).toBe(1);
		expect(result.chatId).toBe("hatter@example.com");
		expect(result.statusEmoji).toBe("🎩");
		expect(result.statusText).toBe("Time for tea!");
	});
});
