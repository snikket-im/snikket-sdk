package test;

import utest.Assert;
import utest.Async;
import borogove.ChatMessageBuilder;

class TestChatMessageBuilder extends utest.Test {
	public function testConvertHtmlToXHTML() {
		final msg = new ChatMessageBuilder();
		msg.setHtml("Hello <div><img src='hai'><br>");
		Assert.equals(
			"<html xmlns=\"http://jabber.org/protocol/xhtml-im\"><body xmlns=\"http://www.w3.org/1999/xhtml\">Hello <div><img src=\"hai\"/><br/></div></body></html>",
			msg.payloads[0].toString()
		);
	}

	public function testConvertHtmlToText() {
		final msg = new ChatMessageBuilder();
		msg.setHtml("<blockquote>Hello<br>you</blockquote><img alt=':boop:'><br><b>hi</b> <em>hi</em> <s>hey</s> <tt>up</tt><pre>hello<br>you");
		Assert.equals(
			"> Hello\n> you\n:boop:\n*hi* _hi_ ~hey~ `up`\n```\nhello\nyou\n```\n",
			msg.text
		);
	}

	public function testConvertHtmlToXHTMLIgnoresBody() {
		final msg = new ChatMessageBuilder();
		msg.setHtml("<body>Hello <div><img src='hai'><br></body>");
		Assert.equals(
			"<html xmlns=\"http://jabber.org/protocol/xhtml-im\"><body xmlns=\"http://www.w3.org/1999/xhtml\">Hello <div><img src=\"hai\"/><br/></div></body></html>",
			msg.payloads[0].toString()
		);
	}

}
