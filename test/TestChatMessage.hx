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
		stanza.addChild(new Stanza("body").text("line 1\n\n*line 2*"));
		stanza.addChild(new Stanza("unstyled", {xmlns: "urn:xmpp:styling:0"}));

		final msg = Message.fromStanza(stanza, JID.parse("bob@example.com"));
		switch (msg.parsed) {
			case ChatMessageStanza(m):
				Assert.equals("<p>line 1</p><p>*line 2*</p>", m.body().toString());
				Assert.equals("line 1\n\n*line 2*", m.body().toPlainText());
			default:
				Assert.fail("Expected ChatMessageStanza");
		}
	}

	public function testUnstyledBodyLineBreak() {
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
				Assert.equals("<p>line 1<br />*line 2*</p>", m.body().toString());
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
				Assert.equals("<p>line 1<br /><strong>line 2</strong></p>", m.body().toString());
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

	public function testStyledBodyWithPreTightAfterPlain() {
		final stanza = new Stanza("message");
		stanza.attr.set("id", "test-id-1");
		stanza.attr.set("from", "alice@example.com");
		stanza.attr.set("to", "bob@example.com");
		stanza.attr.set("type", "chat");
		stanza.addChild(new Stanza("body").text("hello\n```\nlet hello;"));

		final msg = Message.fromStanza(stanza, JID.parse("bob@example.com"));
		switch (msg.parsed) {
			case ChatMessageStanza(m):
				Assert.equals("<p class=\"tight\">hello</p><pre>let hello;\n</pre>", m.body().toString());
				Assert.equals("hello\n```\nlet hello;\n```", m.body().toPlainText());
			default:
				Assert.fail("Expected ChatMessageStanza");
		}
	}

	public function testStyledBodyWithLinkBeaks() {
		final stanza = new Stanza("message");
		stanza.attr.set("id", "test-id-1");
		stanza.attr.set("from", "alice@example.com");
		stanza.attr.set("to", "bob@example.com");
		stanza.attr.set("type", "chat");
		stanza.addChild(new Stanza("body").text("Hey <https://example.com>"));

		final msg = Message.fromStanza(stanza, JID.parse("bob@example.com"));
		switch (msg.parsed) {
			case ChatMessageStanza(m):
				Assert.equals("<p>Hey &lt;<a href=\"https://example.com\">https://example.com</a>&gt;</p>", m.body().toString());
				Assert.equals("Hey <https://example.com>", m.body().toPlainText());
			default:
				Assert.fail("Expected ChatMessageStanza");
		}
	}

	public function testStyledBodyWithLink() {
		final stanza = new Stanza("message");
		stanza.attr.set("id", "test-id-1");
		stanza.attr.set("from", "alice@example.com");
		stanza.attr.set("to", "bob@example.com");
		stanza.attr.set("type", "chat");
		stanza.addChild(new Stanza("body").text("Hey example.com"));

		final msg = Message.fromStanza(stanza, JID.parse("bob@example.com"));
		switch (msg.parsed) {
			case ChatMessageStanza(m):
				Assert.equals("<p>Hey <a href=\"https://example.com\">example.com</a></p>", m.body().toString());
				Assert.equals("Hey example.com", m.body().toPlainText());
			default:
				Assert.fail("Expected ChatMessageStanza");
		}
	}

	public function testSubjectOnlyMessage() {
		final stanza = new Stanza("message");
		stanza.attr.set("id", "test-id-1");
		stanza.attr.set("from", "tea@example.com/hatter");
		stanza.attr.set("to", "bob@example.com");
		stanza.attr.set("type", "groupchat");
		stanza.addChild(new Stanza("thread").text("thread-1"));
		stanza.addChild(new Stanza("subject").text("Tea Time"));

		final msg = Message.fromStanza(stanza, JID.parse("bob@example.com"));
		Assert.equals("thread-1", msg.threadId);
		switch (msg.parsed) {
			case SubjectStanza(subject):
				Assert.equals("Tea Time", subject);
			default:
				Assert.fail("Expected SubjectStanza");
		}
	}

	public function testReactionFallbackShorterContext() {
		// Build a parent message with multiple lines
		final parentBuilder = new borogove.ChatMessageBuilder();
		parentBuilder.localId = "parent-id";
		parentBuilder.from = JID.parse("alice@example.com");
		parentBuilder.to = JID.parse("bob@example.com");
		parentBuilder.senderId = "alice@example.com";
		parentBuilder.setBody(borogove.Html.text("line one\nline two\nline three"));
		final parent = parentBuilder.build();

		// Reply with an emoji (reaction)
		final reply = parent.reply();
		reply.from = JID.parse("bob@example.com");
		reply.to = JID.parse("alice@example.com");
		reply.senderId = "bob@example.com";
		reply.localId = "reply-id";
		reply.setBody(borogove.Html.text("👍"));
		final replyMsg = reply.build();
		final stanza = replyMsg.asStanza();
		final body = stanza.getChildText("body");
		// Reaction should only quote the first line
		Assert.equals("> line one…\n\n👍", body);
	}

	public function testNormalReplyQuotesAllLines() {
		// Build a parent message with multiple lines
		final parentBuilder = new borogove.ChatMessageBuilder();
		parentBuilder.localId = "parent-id";
		parentBuilder.from = JID.parse("alice@example.com");
		parentBuilder.to = JID.parse("bob@example.com");
		parentBuilder.senderId = "alice@example.com";
		parentBuilder.setBody(borogove.Html.text("line one\nline two\nline three"));
		final parent = parentBuilder.build();

		// Reply with normal text
		final reply = parent.reply();
		reply.from = JID.parse("bob@example.com");
		reply.to = JID.parse("alice@example.com");
		reply.senderId = "bob@example.com";
		reply.localId = "reply-id";
		reply.setBody(borogove.Html.text("ok sure"));
		final replyMsg = reply.build();
		final stanza = replyMsg.asStanza();
		final body = stanza.getChildText("body");
		// Normal reply should quote all lines
		Assert.equals("> line one\n> line two\n> line three\n\nok sure", body);
	}

	public function testReactionFallbackSkipsNestedQuotes() {
		// Build a parent message that itself contains a quote and regular text
		final parentBuilder = new borogove.ChatMessageBuilder();
		parentBuilder.localId = "parent-id";
		parentBuilder.from = JID.parse("alice@example.com");
		parentBuilder.to = JID.parse("bob@example.com");
		parentBuilder.senderId = "alice@example.com";
		parentBuilder.setBody(borogove.Html.text("> quoted line\nactual text\nmore text"));
		final parent = parentBuilder.build();

		// Reply with an emoji (reaction)
		final reply = parent.reply();
		reply.from = JID.parse("bob@example.com");
		reply.to = JID.parse("alice@example.com");
		reply.senderId = "bob@example.com";
		reply.localId = "reply-id";
		reply.setBody(borogove.Html.text("❤️"));
		final replyMsg = reply.build();
		final stanza = replyMsg.asStanza();
		final body = stanza.getChildText("body");
		// Reaction should skip the already-quoted line and only quote the first non-quoted line
		Assert.equals("> actual text…\n\n❤️", body);
	}

	public function testMucInviteChatIdIsBare() {
		final stanza = new Stanza("message");
		stanza.attr.set("id", "invite-1");
		stanza.attr.set("from", "alice@example.com/phone");
		stanza.attr.set("to", "bob@example.com");
		stanza.tag("x", { xmlns: "http://jabber.org/protocol/muc#user" })
			.tag("invite", { from: "alice@example.com/phone" })
			.textTag("reason", "join us")
			.up()
			.up();

		final msg = Message.fromStanza(stanza, JID.parse("bob@example.com"));
		Assert.equals("alice@example.com", msg.chatId);
		switch (msg.parsed) {
			case MucInviteStanza(_, _, reason, _): Assert.equals("join us", reason);
			default: Assert.fail("Expected MucInviteStanza");
		}
	}

	public function testSentCarbonInviteIsNotAnInvite() {
		final inner = new Stanza("message", { from: "bob@example.com/phone", to: "alice@example.com", type: "chat" });
		inner.tag("x", { xmlns: "http://jabber.org/protocol/muc#user" })
			.tag("invite", { from: "bob@example.com/phone" })
			.up()
			.up();

		final carbon = new Stanza("message", { from: "bob@example.com", to: "bob@example.com/phone" });
		carbon.tag("sent", { xmlns: "urn:xmpp:carbons:2" })
			.tag("forwarded", { xmlns: "urn:xmpp:forward:0" })
			.addChild(inner);

		final msg = Message.fromStanza(carbon, JID.parse("bob@example.com"));
		Assert.equals("alice@example.com", msg.chatId);
		switch (msg.parsed) {
			case MucInviteStanza(_, _, _, _): Assert.fail("Sent carbon invite should not be processed as an invite");
			default:
		}
	}
}
