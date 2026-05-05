package test;

import utest.Assert;
import utest.Async;

import borogove.ChatMessageBuilder;
import borogove.Html;
import borogove.JID;

@:access(borogove)
class TestChatMessageBuilder extends utest.Test {
	public function testConvertHtmlToXHTML() {
		final msg = new ChatMessageBuilder();
		msg.setBody(Html.fromString("Hello <div><img src='hai'><br>"));
		Assert.equals(
			"<html xmlns=\"http://jabber.org/protocol/xhtml-im\"><body xmlns=\"http://www.w3.org/1999/xhtml\">Hello <div><img src=\"hai\"/><br/></div></body></html>",
			msg.payloads[0].toString()
		);
	}

	public function testConvertHtmlToText() {
		final msg = new ChatMessageBuilder();
		msg.setBody(Html.fromString("<blockquote>Hello<br><br>you</blockquote><img alt=':boop:'><br><b>hi</b> <em>hi</em> <s>hey</s> <tt>up</tt><pre>hello<br>you"));
		Assert.equals(
			"> Hello\n> \n> you\n\n:boop:\n*hi* _hi_ ~hey~ `up`\n```\nhello\nyou\n```",
			msg.text
		);
	}

	public function testConvertHtmlToTextWithLink() {
		final msg = new ChatMessageBuilder();
		msg.setBody(Html.fromString("hello <a href='https://www.example.com/test'>there</a>"));
		Assert.equals(
			"hello there <https://www.example.com/test>",
			msg.text
		);
	}

	public function testConvertHtmlToTextWithLinkTextIsUrl() {
		final msg = new ChatMessageBuilder();
		msg.setBody(Html.fromString("hello <a href='https://www.example.com/test'>https://www.example.com/test</a>"));
		Assert.equals(
			"hello <https://www.example.com/test>",
			msg.text
		);
	}

	public function testConvertHtmlToTextWithLinkTextIsRedundant() {
		final msg = new ChatMessageBuilder();
		msg.setBody(Html.fromString("hello <a href='https://www.example.com/test'>example.com/test</a>"));
		Assert.equals(
			"hello example.com/test",
			msg.text
		);
	}

	public function testConvertHtmlToTextWithParas() {
		final msg = new ChatMessageBuilder();
		msg.setBody(Html.fromString("<blockquote>Hello<br>you</blockquote><img alt=':boop:'><br><b>hi</b> <em>hi</em> <s>hey</s> <tt>up</tt><p>a</p><p>b</p><pre>hello<br>you"));
		Assert.equals(
			"> Hello\n> you\n\n:boop:\n*hi* _hi_ ~hey~ `up`\na\n\nb\n\n```\nhello\nyou\n```",
			msg.text
		);
	}

	public function testConvertHtmlToXHTMLIgnoresBody() {
		final msg = new ChatMessageBuilder();
		msg.setBody(Html.fromString("<body>Hello <div><img src='hai'><br></body>"));
		Assert.equals(
			"<html xmlns=\"http://jabber.org/protocol/xhtml-im\"><body xmlns=\"http://www.w3.org/1999/xhtml\">Hello <div><img src=\"hai\"/><br/></div></body></html>",
			msg.payloads[0].toString()
		);
	}

	public function testSetBodyNull() {
		final msg = new ChatMessageBuilder();
		msg.setBody(Html.text("hello"));
		Assert.equals("hello", msg.text);
		msg.setBody(null);
		Assert.isNull(msg.text);
		Assert.equals(0, msg.payloads.length);
	}

	public function testSetBodyPlainText() {
		final msg = new ChatMessageBuilder();
		msg.setBody(Html.text("hello"));
		Assert.equals("hello", msg.text);
		Assert.equals("<unstyled xmlns=\"urn:xmpp:styling:0\"/>", msg.payloads[0].toString());
	}

	public function testConstructor() {
		final msgText = new ChatMessageBuilder();
		msgText.setBody(Html.text("hello"));
		Assert.equals("hello", msgText.text);
		Assert.equals("<unstyled xmlns=\"urn:xmpp:styling:0\"/>", msgText.payloads[0].toString());

		final msgHtml = new ChatMessageBuilder();
		msgHtml.setBody(Html.fromString("<b>hello</b>"));
		Assert.equals("*hello*", msgHtml.text);
		Assert.equals("<html xmlns=\"http://jabber.org/protocol/xhtml-im\"><body xmlns=\"http://www.w3.org/1999/xhtml\"><b>hello</b></body></html>", msgHtml.payloads[0].toString());
	}

	public function testReceiptRequest() {
		final builder = new ChatMessageBuilder();
		builder.localId = "test-id";
		builder.from = JID.parse("alice@example.com");
		builder.to = JID.parse("bob@example.com");
		builder.senderId = "alice@example.com";
		builder.type = MessageChat;
		builder.setBody(Html.text("Hello"));
		final msg = builder.build();
		final stanza = msg.asStanza();
		Assert.notNull(stanza.getChild("request", "urn:xmpp:receipts"));
	}

	public function testNoReceiptRequestForGroupchat() {
		final builder = new ChatMessageBuilder();
		builder.localId = "test-id";
		builder.from = JID.parse("alice@example.com");
		builder.to = JID.parse("room@example.com");
		builder.senderId = "alice@example.com";
		builder.type = MessageChannel;
		builder.setBody(Html.text("Hello"));
		final msg = builder.build();
		final stanza = msg.asStanza();
		Assert.isNull(stanza.getChild("request", "urn:xmpp:receipts"));
	}
}
