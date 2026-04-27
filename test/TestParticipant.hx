package test;

import utest.Assert;
import utest.Async;
import borogove.Client;
import borogove.Participant;
import borogove.JID;
import borogove.Stanza;
import borogove.persistence.Dummy;

@:access(borogove)
class TestParticipant extends utest.Test {
	public function testStatus(async: Async) {
		final persistence = new Dummy();
		final client = new Client("test@example.com", persistence);
		final participant = new Participant("Friend", null, "", false, [], JID.parse("friend@example.com"), null);

		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "iq" && stanza.attr.get("type") == "get") {
				final pubsub = stanza.getChild("pubsub", "http://jabber.org/protocol/pubsub");
				final items = pubsub?.getChild("items");
				if (items?.attr.get("node") == "http://jabber.org/protocol/activity") {
					final reply = new Stanza("iq", { type: "result", id: stanza.attr.get("id"), from: "friend@example.com", xmlns: "jabber:client" })
						.tag("pubsub", { xmlns: "http://jabber.org/protocol/pubsub" })
							.tag("items", { node: "http://jabber.org/protocol/activity" })
								.tag("item")
									.tag("activity", { xmlns: "http://jabber.org/protocol/activity" })
										.textTag("text", "chilling")
										.tag("undefined")
											.textTag("emoji", "😎", { xmlns: "https://ns.borogove.dev/" })
						.up().up().up().up();
					client.stream.onStanza(reply);
					return EventHandled;
				}
			}
			return EventUnhandled;
		});

		participant.status(client).then(status -> {
			Assert.equals("😎", status.emoji);
			Assert.equals("chilling", status.text);
			async.done();
		});
	}
}
