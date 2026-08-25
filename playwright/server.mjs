import { createReadStream } from "node:fs";
import { createServer } from "node:http";

const server = createServer((request, response) => {
	const pathname = new URL(request.url ?? "/", "http://localhost").pathname;

	switch (pathname) {
		case "/":
			return response.end("");

		case "/idb":
			return response.end(
				`<script type="module">
					import * as borogove from "/borogove.js";
					window.borogove = borogove;
				</script>`,
			);

		case "/sqlite":
			return response.end(
				`<script type="module">
					import * as borogove from "/borogove.js";
					import * as sqlite from "/sqlite-wasm.js";

					window.sqliteWorker1Url = new URL("/sqlite-worker1.js", location.href);
					window.borogove = borogove;
					window.sqlite = sqlite;
				</script>`,
			);

		case "/borogove.js":
			return sendScript(response, "borogove.js");

		case "/sqlite-wasm.js":
			return sendScript(response, "sqlite-wasm.js");

		case "/sqlite-worker1.js":
			return sendScript(response, "sqlite-worker1.js");

		default:
			response.writeHead(404);
			response.end("Not found");
	}
});

function sendScript(response, asset) {
	response.writeHead(200, {
		"Content-Type": "text/javascript; charset=utf-8",
	});
	createReadStream(new URL(`./.cache/${asset}`, import.meta.url)).pipe(
		response,
	);
}

server.listen(49276, ["::1", "127.0.0.1"]);
