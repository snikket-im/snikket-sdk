import { test as base, expect, type JSHandle } from "@playwright/test";

type BrowserFixtures = {
	borogove: JSHandle<any>;
	persistence: JSHandle<any>;
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

export const idbTest = base.extend<BrowserFixtures>({
	page: async ({ page }, use) => {
		await page.goto("/idb");
		await use(page);
	},
	borogove: async ({ page }, use) => {
		const borogove = await page.evaluateHandle(() => window.borogove);
		await use(borogove);
		await borogove.dispose();
	},
	persistence: async ({ page, borogove }, use) => {
		const persistence = await page.evaluateHandle(async (borogove) => {
			const mediaStore = await borogove.persistence.MediaStoreCache("snikket");
			return await borogove.persistence.IDB("snikket", mediaStore);
		}, borogove);
		await use(persistence);
		await persistence.dispose();
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
		await borogove.dispose();
	},
	sqlite: async ({ page }, use) => {
		const sqlite = await page.evaluateHandle(() => window.sqlite);
		await use(sqlite);
		await sqlite.dispose();
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
		await use(persistence);
		await persistence.dispose();
	},
});

export { expect };
