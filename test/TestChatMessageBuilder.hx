package test;

import utest.Assert;
import utest.Async;

import borogove.Html;
import borogove.ChatMessageBuilder;

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
		msg.setBody(Html.fromString("<blockquote>Hello<br>you</blockquote><img alt=':boop:'><br><b>hi</b> <em>hi</em> <s>hey</s> <tt>up</tt><pre>hello<br>you"));
		Assert.equals(
			"> Hello\n> you\n:boop:\n*hi* _hi_ ~hey~ `up`\n```\nhello\nyou\n```",
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
			"> Hello\n> you\n:boop:\n*hi* _hi_ ~hey~ `up`\na\nb\n```\nhello\nyou\n```",
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
		final msgText = new ChatMessageBuilder({ text: "hello" });
		Assert.equals("hello", msgText.text);
		Assert.equals("<unstyled xmlns=\"urn:xmpp:styling:0\"/>", msgText.payloads[0].toString());

		final msgHtml = new ChatMessageBuilder({ html: Html.fromString("<b>hello</b>") });
		Assert.equals("*hello*", msgHtml.text);
		Assert.equals("<html xmlns=\"http://jabber.org/protocol/xhtml-im\"><body xmlns=\"http://www.w3.org/1999/xhtml\"><b>hello</b></body></html>", msgHtml.payloads[0].toString());
	}
}
