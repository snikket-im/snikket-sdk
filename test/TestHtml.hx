package test;

import utest.Assert;
import utest.Async;

import borogove.ChatMessageBuilder;
import borogove.JID;
import borogove.Participant;

@:access(borogove)
class TestHtml extends utest.Test {
	public function testHtmlAsString() {
		final msg = new ChatMessageBuilder();
		msg.localId = "test";
		msg.to = JID.parse("alice@example.com");
		msg.from = JID.parse("hatter@example.com");
		msg.sender = msg.from;
		msg.setHtml("Hello <div class='sup&amp;2'><img src='hai'><br><p></p>");
		Assert.equals(
			"Hello <div class=\"sup&amp;2\"><img src=\"hai\" /><br /><p></p></div>",
			msg.build().html(borogove.Html.asString).join("")
		);
	}

	public function testHashRewrite() {
		final msg = new ChatMessageBuilder();
		msg.localId = "test";
		msg.to = JID.parse("alice@example.com");
		msg.from = JID.parse("hatter@example.com");
		msg.sender = msg.from;
		msg.setHtml("<img src='cid:sha1+472e2207519f825c2affc636550a23cbcf1ef5ac@bob.xmpp.org'/>");
		Assert.equals(
			"<img src=\"ni:///sha-1;Ry4iB1Gfglwq_8Y2VQojy88e9aw\" />",
			msg.build().html(borogove.Html.asString).join("")
		);
	}

	public function testXEP0245() {
		final msg = new ChatMessageBuilder();
		msg.localId = "test";
		msg.to = JID.parse("alice@example.com");
		msg.from = JID.parse("hatter@example.com");
		msg.sender = msg.from;
		msg.text = "/me says hello";

		final participant = new Participant("hatter", null, "", false, msg.from, null);

		Assert.equals(
			"<div class=\"action\"><div>hatter says hello</div></div>",
			msg.build().html(borogove.Html.asString, participant).join("")
		);
	}

	public function testRichXEP0245() {
		final msg = new ChatMessageBuilder();
		msg.localId = "test";
		msg.to = JID.parse("alice@example.com");
		msg.from = JID.parse("hatter@example.com");
		msg.sender = msg.from;
		msg.setHtml("/me says <div class='sup&amp;2'><img src='hai'><br><p></p>");

		final participant = new Participant("hatter", null, "", false, msg.from, null);

		Assert.equals(
			"<div class=\"action\">hatter says <div class=\"sup&amp;2\"><img src=\"hai\" /><br /><p></p></div></div>",
			msg.build().html(borogove.Html.asString, participant).join("")
		);
	}

	public function testRemoveEventAttr() {
		final msg = new ChatMessageBuilder();
		msg.localId = "test";
		msg.to = JID.parse("alice@example.com");
		msg.from = JID.parse("hatter@example.com");
		msg.sender = msg.from;
		msg.setHtml("<a onclick='alert();'>hello</a>");
		Assert.equals(
			"<a>hello</a>",
			msg.build().html(borogove.Html.asString).join("")
		);
	}

	public function testRemoveStyleScript() {
		final msg = new ChatMessageBuilder();
		msg.localId = "test";
		msg.to = JID.parse("alice@example.com");
		msg.from = JID.parse("hatter@example.com");
		msg.sender = msg.from;
		msg.setHtml("<style>hai</style><script>hai</script>hai");
		Assert.equals(
			"hai",
			msg.build().html(borogove.Html.asString).join("")
		);
	}
}
