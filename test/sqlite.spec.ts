import { test } from "vitest";
import * as borogove from "../playwright/.cache/borogove.js";
import * as sqlite from "../playwright/.cache/sqlite-wasm.js";
import { sharedPersistenceTests } from "./persistence-tests";

async function sqliteFixture() {
	const databaseName = "sqlite";
	const mediaStore = await borogove.persistence.MediaStoreCache(
		`${databaseName}-media`,
	);
	window.sqliteWorker1Url = new URL("/sqlite-worker1.js", location.href);
	const persistence = new sqlite.borogove_persistence_Sqlite(
		databaseName,
		mediaStore,
	);
	const storeChats = persistence.storeChats.bind(persistence);
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
	persistence.storeChats = (...args) => {
		storeChats(...args);
		return new Promise((resolve) => setTimeout(resolve, 200));
	};
	const createChannel = (p: any, chatId: string) =>
		new sqlite.Channel(null, null, p, chatId);
	const storeIncompleteMember = async (chatId: string) => {
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
	};
	return { borogove, persistence, createChannel, storeIncompleteMember };
}

const sqlitePersistence = sqliteFixture();
function sqliteTest(name: string, fn: (fixture: any) => Promise<void>) {
	test("sqlite: " + name, async () => {
		const current = await sqlitePersistence;
		await current.persistence.db.exec(
			"DELETE FROM messages; DELETE FROM chats; DELETE FROM keyvaluepairs; DELETE FROM caps; DELETE FROM services; DELETE FROM accounts; DELETE FROM reactions; DELETE FROM members; DELETE FROM omemo_identity_keys; DELETE FROM omemo_devices; DELETE FROM omemo_prekeys; DELETE FROM omemo_signed_prekeys; DELETE FROM omemo_contact_identity_keys; DELETE FROM omemo_sessions; DELETE FROM omemo_sessions_meta;",
		);
		await fn(current);
	});
}

sharedPersistenceTests(sqliteTest);
