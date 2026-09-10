import { defineConfig } from "vitest/config";
import { playwright } from "@vitest/browser-playwright";
import { createReadStream } from "node:fs";

export default defineConfig({
	root: "..",
	plugins: [
		{
			name: "serve-sqlite-worker",
			configureServer(server) {
				server.middlewares.use("/sqlite-worker1.js", (_req, res) => {
					res.setHeader("Content-Type", "text/javascript; charset=utf-8");
					createReadStream(
						new URL("playwright/.cache/sqlite-worker1.js", import.meta.url),
					).pipe(res);
				});
			},
		},
	],
	test: {
		include: ["test/idb.spec.ts", "test/sqlite.spec.ts"],
		browser: {
			enabled: true,
			provider: playwright(),
			headless: true,
			instances: [
				{
					browser: "chromium",
					include: ["test/idb.spec.ts", "test/sqlite.spec.ts"],
				},
				{
					browser: "firefox",
					include: ["test/idb.spec.ts", "test/sqlite.spec.ts"],
				},
				{ browser: "webkit", include: ["test/idb.spec.ts"] },
			],
		},
	},
});
