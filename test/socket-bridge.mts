import { playwright, defineBrowserCommand } from "@vitest/browser-playwright";
import type { Page, WebSocketRoute } from "playwright";

type SocketEvent =
	| { type: "connection" | "close"; connection: string }
	| { type: "message"; connection: string; message: string };
interface HttpResponse {
	url: string;
	body: string;
	contentType: string;
	headers?: Record<string, string>;
}
interface SocketSetup {
	websocketUrls: string[];
	httpResponses: HttpResponse[];
}
interface Bridge {
	websocketUrls: Set<string>;
	sockets: Map<string, WebSocketRoute>;
	events: SocketEvent[];
	responses: HttpResponse[];
	pending?: {
		resolve: (event: SocketEvent) => void;
		reject: (error: Error) => void;
	};
}
const bridges = new WeakMap<Page, Bridge>();
function bridgeFor(page: Page) {
	const bridge = bridges.get(page);
	if (!bridge) throw new Error("Socket bridge is not set up");
	return bridge;
}
function enqueue(bridge: Bridge, event: SocketEvent) {
	if (bridge.pending) bridge.pending.resolve(event);
	else bridge.events.push(event);
}

// WebSocket interception uses an init script and must precede navigation.
export function socketPlaywright() {
	const provider = playwright();
	const createProvider = provider.providerFactory;
	provider.providerFactory = (project) => {
		const instance = createProvider(project);
		const openPage = instance.openPage.bind(instance);
		instance.openPage = async (sessionId, url, options) => {
			await openPage(sessionId, "about:blank", options);
			const { page } = instance.getCommandsContext(sessionId) as { page: Page };
			await page.routeWebSocket(
				() => true,
				(socket) => {
					const bridge = bridges.get(page);
					if (!bridge?.websocketUrls.has(socket.url())) {
						socket.connectToServer();
						return;
					}
					const connection = crypto.randomUUID();
					bridge.sockets.set(connection, socket);
					enqueue(bridge, { type: "connection", connection });
					socket.onMessage((message) => {
						enqueue(bridge, {
							type: "message",
							connection,
							message: message.toString(),
						});
					});
					socket.onClose(() => enqueue(bridge, { type: "close", connection }));
				},
			);
			await page.goto(url, { timeout: 0 });
		};
		return instance;
	};
	return provider;
}

async function finish(page: Page) {
	const bridge = bridges.get(page);
	if (!bridge) return { connectionCount: 0, events: [] as SocketEvent[] };
	bridges.delete(page);
	bridge.pending?.reject(
		new Error("Socket bridge closed while waiting for an event"),
	);
	const result = {
		connectionCount: bridge.sockets.size,
		events: [...bridge.events],
	};
	try {
		await Promise.all(
			[...bridge.sockets.values()].map((socket) => socket.close()),
		);
	} finally {
		await Promise.all(
			bridge.responses.map((response) => page.unroute(response.url)),
		);
		bridge.events.length = 0;
		bridge.sockets.clear();
	}
	return result;
}

export const socketCommands = {
	socketSetup: defineBrowserCommand(
		async ({ page }, { websocketUrls, httpResponses }: SocketSetup) => {
			await finish(page);
			bridges.set(page, {
				websocketUrls: new Set(websocketUrls),
				sockets: new Map(),
				events: [],
				responses: httpResponses,
			});
			for (const { url, ...response } of httpResponses) {
				await page.route(url, (route) => route.fulfill(response));
			}
		},
	),
	socketNextEvent: defineBrowserCommand(({ page }): Promise<SocketEvent> => {
		const bridge = bridgeFor(page);
		if (bridge.pending)
			throw new Error("Only one socket event read may be pending");
		const event = bridge.events.shift();
		if (event) return Promise.resolve(event);
		return new Promise((resolve, reject) => {
			const timer = setTimeout(() => {
				bridge.pending = undefined;
				reject(new Error("Timed out after 5000ms waiting for a socket event"));
			}, 5000);
			bridge.pending = {
				resolve: (event) => {
					clearTimeout(timer);
					bridge.pending = undefined;
					resolve(event);
				},
				reject: (error) => {
					clearTimeout(timer);
					bridge.pending = undefined;
					reject(error);
				},
			};
		});
	}),
	socketSend: defineBrowserCommand(
		({ page }, connection: string, message: string) => {
			const socket = bridgeFor(page).sockets.get(connection);
			if (!socket) throw new Error(`Unknown socket connection: ${connection}`);
			socket.send(message);
		},
	),
	socketFinish: defineBrowserCommand(({ page }) => finish(page)),
};

declare module "vitest/browser" {
	interface BrowserCommands {
		socketSetup: (options: SocketSetup) => Promise<void>;
		socketNextEvent: () => Promise<SocketEvent>;
		socketSend: (connection: string, message: string) => Promise<void>;
		socketFinish: () => Promise<{
			connectionCount: number;
			events: SocketEvent[];
		}>;
	}
}
