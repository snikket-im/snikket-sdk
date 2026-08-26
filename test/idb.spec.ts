import { idbTest as test, expect } from "./browser-test";
import { sharedPersistenceTests } from "./persistence-tests";

sharedPersistenceTests(test);

// TODO: Share this with SQLite once direct-chat reply hydration is fixed.
test("hydrate message with incomplete replyToMessage", async ({
	page,
	borogove,
	persistence,
}) => {
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
		{ borogove, persistence },
	);

	expect(result).toBe("Hello");
});

test("hydrate message with incomplete replyToMessage keys", async ({
	page,
	borogove,
	persistence,
}) => {
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

			await persistence.storeMessages("alice@example.com", [
				parentMsg,
				childMsg,
			]);

			const db = await new Promise<IDBDatabase>((resolve, reject) => {
				const req = indexedDB.open("snikket");
				req.onsuccess = () => resolve(req.result);
				req.onerror = () => reject(req.error);
			});
			const tx = db.transaction(["messages"], "readwrite");
			const store = tx.objectStore("messages");
			const key = ["alice@example.com", "child", "hatter@example.com", "loc2"];
			const rawChild = await new Promise<{ replyToMessage: string[] }>(
				(resolve) => {
					const req = store.get(key);
					req.onsuccess = () => resolve(req.result);
				},
			);

			rawChild.replyToMessage = ["alice@example.com", "parent", "", ""];

			await new Promise<void>((resolve) => {
				const req = store.put(rawChild);
				req.onsuccess = () => resolve();
			});
			await new Promise<void>((resolve) => {
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
		},
		{ borogove, persistence },
	);

	expect(result.hasReply).toBe(true);
	expect(result.replyServerId).toBe("parent");
});
