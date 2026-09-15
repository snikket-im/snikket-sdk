import { defineConfig } from "vitest/config";
import { createReadStream } from "node:fs";

import { socketCommands, socketPlaywright } from "./test/socket-bridge.mts";

export default defineConfig({
	root: "..",
	optimizeDeps: { include: ["@xmpp/xml", "ltx"] },
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
		silent: "passed-only",
		include: [
			"test/idb.spec.ts",
			"test/sqlite.spec.ts",
			"test/fast-auth.spec.ts",
		],
		browser: {
			enabled: true,
			provider: socketPlaywright(),
			commands: socketCommands,
			headless: true,
			instances: [
				{
					browser: "chromium",
					include: [
						"test/idb.spec.ts",
						"test/sqlite.spec.ts",
						"test/fast-auth.spec.ts",
					],
				},
				{
					browser: "firefox",
					include: [
						"test/idb.spec.ts",
						"test/sqlite.spec.ts",
						"test/fast-auth.spec.ts",
					],
				},
				{
					browser: "webkit",
					include: ["test/idb.spec.ts", "test/fast-auth.spec.ts"],
				},
			],
		},
	},
});
