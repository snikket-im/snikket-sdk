import { expect, test } from "vitest";
import { commands } from "vitest/browser";
import xml from "@xmpp/xml";
import { parse } from "ltx";
import * as borogove from "../playwright/.cache/borogove.js";
import type {} from "./socket-bridge.mts";

const BIND2 = "urn:xmpp:bind:0";
const SASL2 = "urn:xmpp:sasl:2";
const FRAMING = "urn:ietf:params:xml:ns:xmpp-framing";
const SASL = "urn:ietf:params:xml:ns:xmpp-sasl";
const STREAM = "http://etherx.jabber.org/streams";

const websocketUrl = "ws://127.0.0.1/xmpp";

const HOST_META = xml(
	"XRD",
	{ xmlns: "http://docs.oasis-open.org/ns/xri/xrd-1.0" },
	xml("Link", {
		rel: "urn:xmpp:alt-connections:websocket",
		href: websocketUrl,
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

async function nextStanza(connection: string, name: string, namespace: string) {
	const event = await commands.socketNextEvent();
	expect(event).toMatchObject({ type: "message", connection });
	if (event.type !== "message") throw new Error("Expected a socket message");
	const stanza = parse(event.message);
	expect(stanza.is(name, namespace), event.message).toBe(true);
	return stanza;
}

async function nextConnection() {
	const event = await commands.socketNextEvent();
	expect(event.type).toBe("connection");
	return event.connection;
}

test("a rejected unexpired FAST token uses a non-empty password before reconnecting", async () => {
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
	const client = new borogove.Client("tester@127.0.0.1", persistence);
	let passwordRequested = false;
	client.addPasswordNeededListener(() => {
		passwordRequested = true;
	});

	try {
		await commands.socketSetup({
			websocketUrls: [websocketUrl],
			httpResponses: [
				{
					url: "https://127.0.0.1/.well-known/host-meta",
					body: HOST_META,
					contentType: "application/xrd+xml",
					headers: { "Access-Control-Allow-Origin": "*" },
				},
			],
		});
		client.start();
		const first = await nextConnection();
		await nextStanza(first, "open", FRAMING);
		await commands.socketSend(first, OPEN);
		await commands.socketSend(first, FEATURES);
		const fast = await nextStanza(first, "authenticate", SASL2);
		expect(fast.attrs.mechanism).toBe("HT-SHA-256-NONE");
		expect(fast.getChildText("initial-response")).toBe(
			"dGVzdGVyANlEKT65Z6grrZHbeSjhb05VNRnDs6X1T3Wh0pHQg7cv",
		);
		await commands.socketSend(first, NOT_AUTHORIZED);
		const plain = await nextStanza(first, "authenticate", SASL2);
		expect(plain.attrs.mechanism).toBe("PLAIN");
		const [, username, password] = atob(
			plain.getChildText("initial-response"),
		).split("\0");
		expect(username).toBe("tester");
		expect(password).toBeTruthy();
		expect(password).not.toBe("persisted secret");
		await commands.socketSend(first, NOT_AUTHORIZED);
		const second = await nextConnection();
		expect(second).not.toBe(first);
		await nextStanza(second, "open", FRAMING);
		await commands.socketSend(second, OPEN);
		await commands.socketSend(second, FEATURES);
		await expect.poll(() => passwordRequested).toBe(true);
		client.stream.disconnect();
		await nextStanza(second, "close", FRAMING);
		await commands.socketSend(second, CLOSE);
		expect(await commands.socketNextEvent()).toEqual({
			type: "close",
			connection: second,
		});
		expect(await commands.socketFinish()).toEqual({
			connectionCount: 2,
			events: [],
		});
	} finally {
		try {
			client.stream.disconnect();
		} finally {
			await commands.socketFinish();
		}
	}
}, 30000);
