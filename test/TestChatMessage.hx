package test;

import utest.Assert;
import borogove.Stanza;
import borogove.ChatMessage;
import borogove.JID;
import borogove.Message;

@:access(borogove)
class TestChatMessage extends utest.Test {
	public function testUnstyledBody() {
		final stanza = new Stanza("message");
		stanza.attr.set("id", "test-id-1");
		stanza.attr.set("from", "alice@example.com");
		stanza.attr.set("to", "bob@example.com");
		stanza.attr.set("type", "chat");
		stanza.addChild(new Stanza("body").text("line 1\n*line 2*"));
		stanza.addChild(new Stanza("unstyled", {xmlns: "urn:xmpp:styling:0"}));

		final msg = Message.fromStanza(stanza, JID.parse("bob@example.com"));
		switch (msg.parsed) {
			case ChatMessageStanza(m):
				Assert.equals("<div>line 1</div><div>*line 2*</div>", m.body().toString());
				Assert.equals("line 1\n*line 2*", m.body().toPlainText());
			default:
				Assert.fail("Expected ChatMessageStanza");
		}
	}

	public function testStyledBody() {
		final stanza = new Stanza("message");
		stanza.attr.set("id", "test-id-1");
		stanza.attr.set("from", "alice@example.com");
		stanza.attr.set("to", "bob@example.com");
		stanza.attr.set("type", "chat");
		stanza.addChild(new Stanza("body").text("line 1\n*line 2*"));

		final msg = Message.fromStanza(stanza, JID.parse("bob@example.com"));
		switch (msg.parsed) {
			case ChatMessageStanza(m):
				Assert.equals("<div>line 1</div><div><strong>line 2</strong></div>", m.body().toString());
				Assert.equals("line 1\n*line 2*", m.body().toPlainText());
			default:
				Assert.fail("Expected ChatMessageStanza");
		}
	}

	public function testStyledBodyWithCodeBlock() {
		final stanza = new Stanza("message");
		stanza.attr.set("id", "test-id-1");
		stanza.attr.set("from", "alice@example.com");
		stanza.attr.set("to", "bob@example.com");
		stanza.attr.set("type", "chat");
		stanza.addChild(new Stanza("body").text("```javascript\nlet hello;\n```"));

		final msg = Message.fromStanza(stanza, JID.parse("bob@example.com"));
		switch (msg.parsed) {
			case ChatMessageStanza(m):
				Assert.equals("<pre><code class=\"language-javascript\">let hello;\n</code></pre>", m.body().toString());
				Assert.equals("```javascript\nlet hello;\n```", m.body().toPlainText());
			default:
				Assert.fail("Expected ChatMessageStanza");
		}
	}

	public function testStyledBodyWithPreBlock() {
		final stanza = new Stanza("message");
		stanza.attr.set("id", "test-id-1");
		stanza.attr.set("from", "alice@example.com");
		stanza.attr.set("to", "bob@example.com");
		stanza.attr.set("type", "chat");
		stanza.addChild(new Stanza("body").text("```\nlet hello;"));

		final msg = Message.fromStanza(stanza, JID.parse("bob@example.com"));
		switch (msg.parsed) {
			case ChatMessageStanza(m):
				Assert.equals("<pre>let hello;\n</pre>", m.body().toString());
				Assert.equals("```\nlet hello;\n```", m.body().toPlainText());
			default:
				Assert.fail("Expected ChatMessageStanza");
		}
	}
}
