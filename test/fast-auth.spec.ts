import { expect, test } from "@playwright/test";
import fs from "fs";
import xml from "@xmpp/xml";
import { parse } from "ltx";

const BIND2 = "urn:xmpp:bind:0";
const SASL2 = "urn:xmpp:sasl:2";
const FRAMING = "urn:ietf:params:xml:ns:xmpp-framing";
const SASL = "urn:ietf:params:xml:ns:xmpp-sasl";
const STREAM = "http://etherx.jabber.org/streams";
const BOROGOVE_CODE = fs.readFileSync("playwright/.cache/borogove.js", "utf8");

const HOST_META = xml(
	"XRD",
	{ xmlns: "http://docs.oasis-open.org/ns/xri/xrd-1.0" },
	xml("Link", {
		rel: "urn:xmpp:alt-connections:websocket",
		href: "ws://127.0.0.1/xmpp",
	}),
).toString();
const OPEN = xml("open", {
	from: "127.0.0.1",
	id: "stream",
	version: "1.0",
	xmlns: FRAMING,
}).toString();
const FEATURES = xml(
	"stream:features",
	{ xmlns: "jabber:client", "xmlns:stream": STREAM },
	xml(
		"authentication",
		{ xmlns: SASL2 },
		xml("mechanism", {}, "PLAIN"),
		xml("mechanism", {}, "SCRAM-SHA-1"),
		xml(
			"inline",
			{},
			xml(
				"fast",
				{ xmlns: "urn:xmpp:fast:0" },
				xml("mechanism", {}, "HT-SHA-256-NONE"),
			),
			xml("bind", { xmlns: BIND2 }),
		),
	),
).toString();
const NOT_AUTHORIZED = xml(
	"failure",
	{ xmlns: SASL2 },
	xml("not-authorized", { xmlns: SASL }),
).toString();
const CLOSE = xml("close", { xmlns: FRAMING }).toString();

test.beforeEach(async ({ page }) => {
	await page.route("https://localhost/", (route) =>
		route.fulfill({ body: "<html></html>" }),
	);
	await page.route("https://127.0.0.1/.well-known/host-meta", (route) =>
		route.fulfill({
			body: HOST_META,
			contentType: "application/xrd+xml",
		}),
	);
});

test("a rejected unexpired FAST token uses a non-empty password before reconnecting", async ({
	page,
}) => {
	let connectionCount = 0;
	let resolveSocketClosed: () => void;
	const socketClosed = new Promise<void>((resolve) => {
		resolveSocketClosed = resolve;
	});
	await page.routeWebSocket("ws://127.0.0.1/xmpp", (socket) => {
		connectionCount++;
		socket.onMessage((message: string) => {
			const stanza = parse(message);
			expect(stanza.is("open", FRAMING)).toBe(true);
			if (connectionCount === 2) {
				socket.onMessage((message: string) => {
					const stanza = parse(message);
					expect(stanza.is("close", FRAMING)).toBe(true);
					socket.send(CLOSE);
				});
				socket.send(OPEN);
				socket.send(FEATURES);
				return;
			}
			socket.onMessage((message: string) => {
				const stanza = parse(message);
				expect(stanza.is("authenticate", SASL2)).toBe(true);
				expect(stanza.attrs.mechanism).toBe("HT-SHA-256-NONE");
				expect(stanza.getChildText("initial-response")).toBe(
					"dGVzdGVyANlEKT65Z6grrZHbeSjhb05VNRnDs6X1T3Wh0pHQg7cv",
				);
				socket.onMessage((message: string) => {
					const stanza = parse(message);
					expect(stanza.is("authenticate", SASL2)).toBe(true);
					expect(stanza.attrs.mechanism).toBe("PLAIN");
					const [, username, password] = atob(
						stanza.getChildText("initial-response"),
					).split("\0");
					expect(username).toBe("tester");
					expect(password).not.toBe("");
					expect(password).not.toBe("persisted secret");
					socket.send(NOT_AUTHORIZED);
				});
				socket.send(NOT_AUTHORIZED);
			});
			socket.send(OPEN);
			socket.send(FEATURES);
		});
		socket.onClose(() => resolveSocketClosed());
	});
	await page.goto("https://localhost/");

	await page.evaluate(
		async ({ code }) => {
			const moduleUrl = URL.createObjectURL(
				new Blob([code], { type: "text/javascript" }),
			);
			const borogove = await import(moduleUrl);
			const persistence = new borogove.persistence.Dummy();
			persistence.getLogin = async () => ({
				clientId: "test-client",
				displayName: "Test",
				fastCount: 0,
				token: JSON.stringify({
					token: "persisted secret",
					expiry: "2099-01-01T00:00:00Z",
					mechanism: "HT-SHA-256-NONE",
				}),
			});
			persistence.getStreamManagement = async () => ({
				sortId: "a ",
				sm: null,
			});
			persistence.getChats = async () => [];
			persistence.getChatsUnreadDetails = async () => [];
			const client = new borogove.Client(
				"tester@127.0.0.1",
				persistence,
			);
			client.stream.debug = false;
			const passwordRequested = Promise.withResolvers<void>();
			client.addPasswordNeededListener(() => {
				passwordRequested.resolve();
			});
			client.start();
			await passwordRequested.promise;
			client.stream.disconnect();
		},
		{ code: BOROGOVE_CODE },
	);
	await socketClosed;
	expect(connectionCount).toBe(2);
});
