import { expect, test } from "vitest";
import * as borogove from "../playwright/.cache/borogove.js";
import { createFactories } from "./persistence-factories";
import { sharedPersistenceTests } from "./persistence-tests";

async function idbFixture() {
	const databaseName = `idb-${crypto.randomUUID()}`;
	const mediaStore = await borogove.persistence.MediaStoreCache(
		`${databaseName}-media`,
	);
	const persistence = await borogove.persistence.IDB(databaseName, mediaStore);
	const createChannel = (p: any, chatId: string) =>
		new borogove.Channel(null, null, p, chatId);
	const storeIncompleteMember = async (chatId: string) => {
		const request = indexedDB.open(databaseName);
		const db = await new Promise<IDBDatabase>((resolve, reject) => {
			request.onsuccess = () => resolve(request.result);
			request.onerror = () => reject(request.error);
		});
		const transaction = db.transaction(["members"], "readwrite");
		transaction.objectStore("members").put({
			account: "alice@example.com",
			chatId,
			id: "room-members-7@example.com/incomplete",
			displayName: "",
			photoUri: null,
			isSelf: 0,
			chat: "",
			roles: [],
			presence: new Map(),
			jid: "",
		});
		await new Promise<void>((resolve, reject) => {
			transaction.oncomplete = () => resolve();
			transaction.onerror = () => reject(transaction.error);
		});
	};
	return {
		factories: createFactories(borogove),
		borogove,
		persistence,
		createChannel,
		storeIncompleteMember,
		databaseName,
	};
}

function idbTest(name: string, fn: (fixture: any) => Promise<void>) {
	test("idb: " + name, async () => {
		const current = await idbFixture();
		await fn(current);
	});
}

sharedPersistenceTests(idbTest);

idbTest(
	"hydrate message with incomplete replyToMessage keys",
	async ({ borogove, persistence, databaseName }) => {
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
		const db = await new Promise<IDBDatabase>((resolve, reject) => {
			const request = indexedDB.open(databaseName);
			request.onsuccess = () => resolve(request.result);
			request.onerror = () => reject(request.error);
		});
		const transaction = db.transaction(["messages"], "readwrite");
		const store = transaction.objectStore("messages");
		const rawChild = await new Promise<{ replyToMessage: string[] }>(
			(resolve, reject) => {
				const request = store.get([
					"alice@example.com",
					"child",
					"hatter@example.com",
					"loc2",
				]);
				request.onsuccess = () => resolve(request.result);
				request.onerror = () => reject(request.error);
			},
		);
		rawChild.replyToMessage = ["alice@example.com", "parent", "", ""];
		store.put(rawChild);
		await new Promise<void>((resolve, reject) => {
			transaction.oncomplete = () => resolve();
			transaction.onerror = () => reject(transaction.error);
		});

		const retrievedChild = await persistence.getMessage(
			"alice@example.com",
			"hatter@example.com",
			"child",
			"loc2",
		);
		expect(!!retrievedChild.replyToMessage).toBe(true);
		expect(retrievedChild.replyToMessage?.serverId).toBe("parent");
	},
);
