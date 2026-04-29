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

		console.log("made persistence");
		await new Promise((resolve) => setTimeout(resolve, 3000));

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
		  throw "" + e.result;
		}
	  },
	  [code, sqlite, worker1],
	);

	expect(result.length).toBe(2);
	expect(result[0].serverId).toBe("1");
	expect(result[1].serverId).toBe("2");
  });
});
