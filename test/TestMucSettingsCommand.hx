package test;

import utest.Assert;
import utest.Async;
import borogove.Client;
import borogove.Stanza;
import borogove.JID;
import borogove.persistence.Dummy;
import borogove.MucSettingsCommand;
import borogove.Form;

@:access(borogove)
class TestMucSettingsCommand extends utest.Test {
	public function testExecuteSuccess(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final command = new MucSettingsCommand(client, JID.parse("channel@example.com"));

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "iq" && stanza.attr.get("type") == "get") {
				Assert.equals("channel@example.com", stanza.attr.get("to"));
				final query = stanza.getChild("query", "http://jabber.org/protocol/muc#owner");
				if (query != null) {
					final responseStanza = new Stanza("iq", { xmlns: "jabber:client", type: "result", id: stanza.attr.get("id"), from: "channel@example.com", to: "test@example.com" })
						.tag("query", { xmlns: "http://jabber.org/protocol/muc#owner" })
							.tag("x", { xmlns: "jabber:x:data", type: "form" })
								.tag("field", { "var": "muc#roomconfig_roomname" })
									.textTag("value", "Test Room")
								.up()
							.up()
						.up();

					client.stream.onStanza(responseStanza);
					return EventHandled;
				}
			}
			return EventUnhandled;
		});

		command.execute().then(session -> {
			Assert.equals("executing", session.status);
			Assert.equals(1, session.forms.length);
			Assert.notNull(session.forms[0]);

			client.stream.on("sendStanza", (stanza: Stanza) -> {
				if (stanza.name == "iq" && stanza.attr.get("type") == "set") {
					final query = stanza.getChild("query", "http://jabber.org/protocol/muc#owner");
					if (query != null) {
						final x = query.getChild("x", "jabber:x:data");
						Assert.notNull(x);

						final responseStanza = new Stanza("iq", { xmlns: "jabber:client", type: "result", id: stanza.attr.get("id"), from: "channel@example.com", to: "test@example.com" });
						client.stream.onStanza(responseStanza);
						return EventHandled;
					}
				}
				return EventUnhandled;
			});

			#if js
			final data = {};
			#else
			final data = new borogove.Form.FormSubmitBuilder();
			#end

			session.execute(null, data, 0).then(nextSession -> {
				Assert.equals("completed", nextSession.status);
				Assert.equals(0, nextSession.forms.length);
				async.done();
			}, err -> {
				Assert.fail(err);
			});
		}, err -> {
			Assert.fail(err);
		});
	}

	public function testExecuteGetError(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final command = new MucSettingsCommand(client, JID.parse("channel@example.com"));

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "iq" && stanza.attr.get("type") == "get") {
				final query = stanza.getChild("query", "http://jabber.org/protocol/muc#owner");
				if (query != null) {
					final responseStanza = new Stanza("iq", { xmlns: "jabber:client", type: "error", id: stanza.attr.get("id"), from: "channel@example.com", to: "test@example.com" })
						.tag("error", { type: "auth" })
							.tag("forbidden", { xmlns: "urn:ietf:params:xml:ns:xmpp-stanzas" }).up()
						.up();

					client.stream.onStanza(responseStanza);
					return EventHandled;
				}
			}
			return EventUnhandled;
		});

		command.execute().then(session -> {
			Assert.equals("error", session.status);
			Assert.equals(1, session.forms.length);
			async.done();
		}, err -> {
			Assert.fail(err);
		});
	}

	public function testSessionCancel(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final command = new MucSettingsCommand(client, JID.parse("channel@example.com"));

		final session = new borogove.MucSettingsCommand.MucSettingsCommandSession("executing", null, [], [], command);

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			Assert.fail("Should not send IQ on cancel");
			return EventHandled;
		});

		session.execute("cancel", null, 0).then(nextSession -> {
			Assert.equals("canceled", nextSession.status);
			async.done();
		}, err -> {
			Assert.fail(err);
		});
	}
}
