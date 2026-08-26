import { sqliteTest as test, expect } from "./browser-test";
import { sharedPersistenceTests } from "./persistence-tests";

test.describe("not webkit", () => {
	test.skip(
		({ browserName }) => browserName === "webkit",
		"Skip on webkit because the version in playwright lacks OPFS",
	);

	sharedPersistenceTests(test);

	test("getMembers filters hidden rows for non-moderators", async ({
		page,
		borogove,
		persistence,
	}) => {
		const result = await page.evaluate(
			async ({ borogove, persistence }) => {
				const chat = new borogove.Channel(
					null,
					null,
					persistence,
					"room-members-5@example.com",
				);
				chat.displayName = "A Chat";
				chat.trusted = true;

				await persistence.storeMembers("alice@example.com", chat.chatId, [
					{
						id: "room-members-5@example.com/owner",
						displayName: "Zulu",
						photoUri: null,
						isSelf: false,
						roles: [{ id: "owner", title: "Owner" }],
						jid: borogove.JID.parse("zulu@example.com"),
						presence: new Map([
							["desk", borogove.Stanza.parse("<presence />")],
						]),
						chat: { chatId: "zulu@example.com" },
					},
					{
						id: "room-members-5@example.com/outcast",
						displayName: "Banned",
						photoUri: null,
						isSelf: false,
						roles: [{ id: "outcast", title: "Banned" }],
						jid: borogove.JID.parse("banned@example.com"),
						presence: new Map([
							["desk", borogove.Stanza.parse("<presence />")],
						]),
						chat: { chatId: "banned@example.com" },
					},
					{
						id: "room-members-5@example.com/guest-offline",
						displayName: "Guest",
						photoUri: null,
						isSelf: false,
						roles: [{ id: "none", title: "Guest" }],
						jid: borogove.JID.parse("guest@example.com"),
						presence: new Map([
							[
								"desk",
								borogove.Stanza.parse('<presence type="unavailable" />'),
							],
						]),
						chat: { chatId: "guest@example.com" },
					},
					{
						id: "room-members-5@example.com/admin",
						displayName: "Alpha",
						photoUri: null,
						isSelf: false,
						roles: [{ id: "admin", title: "Admin" }],
						jid: borogove.JID.parse("alpha@example.com"),
						presence: new Map([
							["desk", borogove.Stanza.parse("<presence />")],
						]),
						chat: { chatId: "alpha@example.com" },
					},
				]);

				const members = await persistence.getMembers(
					"alice@example.com",
					chat,
					false,
				);
				return members.map((m) => m.displayName);
			},
			{ borogove, persistence },
		);

		expect(result).toEqual(["Zulu", "Alpha"]);
	});
});
