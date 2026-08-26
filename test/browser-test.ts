import {
	test as base,
	expect,
	type JSHandle,
	type Page,
} from "@playwright/test";
import type { borogove_Persistence } from "../npm/borogove-browser";
import type { borogove_persistence_Sqlite } from "../npm/sqlite-wasm";

type PageKeyPair = {
	privKey: number[];
	pubKey: number[];
};

type PageHelpers = {
	keyToBuffer(key: number[]): ArrayBuffer;
	bufferToKey(key: ArrayBuffer): number[];
	keyPairToBuffers(keyPair: PageKeyPair): {
		privKey: ArrayBuffer;
		pubKey: ArrayBuffer;
	};
	buffersToKeyPair(keyPair: {
		privKey: ArrayBuffer;
		pubKey: ArrayBuffer;
	}): PageKeyPair;
};

type BrowserFixtures = {
	borogove: JSHandle<any>;
	createChannel: JSHandle<any>;
	pageHelpers: JSHandle<PageHelpers>;
	persistence: JSHandle<borogove_Persistence>;
	storeIncompleteMember: JSHandle<any>;
};

type SqliteFixtures = BrowserFixtures & {
	sqlite: JSHandle<any>;
};

declare global {
	interface Window {
		borogove: any;
		sqlite: any;
		sqliteWorker1Url: URL;
	}
}

const pageHelpers = async (
	{ page }: { page: Page },
	use: (helpers: JSHandle<PageHelpers>) => Promise<void>,
) => {
	const helpers = await page.evaluateHandle(() => ({
		keyToBuffer: (key: number[]) => new Uint8Array(key).buffer,
		bufferToKey: (key: ArrayBuffer) => [...new Uint8Array(key)],
		keyPairToBuffers: (keyPair: PageKeyPair) => ({
			privKey: new Uint8Array(keyPair.privKey).buffer,
			pubKey: new Uint8Array(keyPair.pubKey).buffer,
		}),
		buffersToKeyPair: (keyPair: {
			privKey: ArrayBuffer;
			pubKey: ArrayBuffer;
		}) => ({
			privKey: [...new Uint8Array(keyPair.privKey)],
			pubKey: [...new Uint8Array(keyPair.pubKey)],
		}),
	}));
	await use(helpers);
};

export const idbTest = base.extend<BrowserFixtures>({
	page: async ({ page }, use) => {
		await page.goto("/idb");
		await use(page);
	},
	borogove: async ({ page }, use) => {
		const borogove = await page.evaluateHandle(() => window.borogove);
		await use(borogove);
	},
	pageHelpers,
	createChannel: async ({ page, borogove }, use) => {
		const createChannel = await page.evaluateHandle(
			(borogove) => (persistence, chatId) =>
				new borogove.Channel(null, null, persistence, chatId),
			borogove,
		);
		await use(createChannel);
	},
	persistence: async ({ page, borogove }, use) => {
		const persistence = await page.evaluateHandle(async (borogove) => {
			const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
			return borogove.persistence.IDB("snikket", mediaStore);
		}, borogove);
		await use(persistence);
	},
	storeIncompleteMember: async ({ page }, use) => {
		const storeIncompleteMember = await page.evaluateHandle(
			() => async (chatId) => {
				const request = indexedDB.open("snikket");
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
				await new Promise((resolve, reject) => {
					transaction.oncomplete = () => resolve(null);
					transaction.onerror = () => reject(transaction.error);
				});
			},
		);
		await use(storeIncompleteMember);
	},
});

export const sqliteTest = base.extend<SqliteFixtures>({
	page: async ({ page }, use) => {
		await page.goto("/sqlite");
		await use(page);
	},
	borogove: async ({ page }, use) => {
		const borogove = await page.evaluateHandle(() => window.borogove);
		await use(borogove);
	},
	pageHelpers,
	sqlite: async ({ page }, use) => {
		const sqlite = await page.evaluateHandle(() => window.sqlite);
		await use(sqlite);
	},
	createChannel: async ({ page, sqlite }, use) => {
		const createChannel = await page.evaluateHandle(
			(sqlite) => (persistence, chatId) =>
				new sqlite.Channel(null, null, persistence, chatId),
			sqlite,
		);
		await use(createChannel);
	},
	persistence: async ({ page, borogove, sqlite }, use) => {
		const persistence = await page.evaluateHandle(
			async ({ borogove, sqlite }) => {
				const mediaStore =
					await borogove.persistence.MediaStoreCache("snikket");
				return new sqlite.borogove_persistence_Sqlite("snikket", mediaStore);
			},
			{ borogove, sqlite },
		);
		await page.evaluate((persistence: borogove_persistence_Sqlite) => {
			// TODO: remove this wrapper
			//
			// storeChats is not currently awaitable. The Sqlite tests were adding
			// manual delays that the IDB tests didn't need. I wanted to share the
			// tests, so wrapping the implementation with a delay here lets me do
			// that.
			//
			// Changing storeChats to return a Promise that could be awaited would
			// be the better long term solution, but there's already a debounce
			// thing in storeChats itself that maybe should be revisited and that
			// seemed like a riskier change, so I went with this for now.
			const storeChats = persistence.storeChats.bind(persistence);
			persistence.storeChats = (...args) => {
				storeChats(...args);
				return new Promise((resolve) => setTimeout(resolve, 200));
			};
		}, persistence);
		await use(persistence);
	},
	storeIncompleteMember: async ({ page, persistence }, use) => {
		const storeIncompleteMember = await page.evaluateHandle(
			(persistence) => async (chatId) => {
				await persistence.db.exec(
					"INSERT INTO members(account_id, chat_id, member_id, display_name, photo_uri, is_self, chat, roles, presence, jid) VALUES(?, ?, ?, ?, ?, ?, ?, jsonb(?), jsonb(?), ?)",
					[
						"alice@example.com",
						chatId,
						"room-members-7@example.com/incomplete",
						"",
						null,
						0,
						"{}",
						"[]",
						"{}",
						"",
					],
				);
			},
			persistence,
		);
		await use(storeIncompleteMember);
	},
});

export { expect };
