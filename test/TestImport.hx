package test;

import utest.Assert;

import borogove.Import;
import borogove.Message;
import borogove.JID;

class TestImport extends utest.Test {
	public function testOnAccount() {
		final accounts = [];

		final i = new Import(null);
		i.onAccount = (id) -> {
			accounts.push(id);
		};
		i.write("<server-data xmlns='urn:xmpp:pie:0' xmlns:ns0='urn:xmpp:pie:0'>");
		i.write("<host jid='capulet.com'>");
		i.write("<user name='juliet' />");
		i.write("</host>");
		i.write("<ns0:host jid='montague.net'>");
		i.write("<ns0:user name='romeo' />");
		i.write("</ns0:host>");
		i.write("</server-data>");

		Assert.equals(2, accounts.length);
		Assert.equals("juliet@capulet.com", accounts[0]);
		Assert.equals("romeo@montague.net", accounts[1]);
	}

	public function testOnChannel() {
		final channels = [];

		final i = new Import(null);
		i.onChannel = (id) -> {
			channels.push(id);
		};
		i.write("<server-data xmlns='urn:xmpp:pie:0'>");
		i.write("<component xmlns='urn:xmpp:pie:0#component' jid='capulet.com' type='muc'>");
		i.write("<item name='party' />");
		i.write("</component>");
		i.write("<component xmlns='urn:xmpp:pie:0#component' jid='other.capulet.com' type='other'>");
		i.write("<item name='party' />");
		i.write("</component>");
		i.write("</server-data>");

		Assert.equals(1, channels.length);
		Assert.equals("party@capulet.com", channels[0]);
	}

	public function testOnMamItem() {
		final items = [];

		final i = new Import(null);
		i.onMessage = (source, msg) -> {
			items.push(msg);
		};
		i.write("<server-data xmlns='urn:xmpp:pie:0'>");
		i.write("<host jid='capulet.com'>");
		i.write("<user name='juliet'>");
		i.write("<archive xmlns='urn:xmpp:pie:0#mam'>");
		i.write("<result xmlns='urn:xmpp:mam:2' id='mam-id-1'>");
		i.write("<forwarded xmlns='urn:xmpp:forward:0'>");
		i.write("<delay xmlns='urn:xmpp:delay' stamp='2023-10-27T10:00:00Z' />");
		i.write("<message xmlns='jabber:client' from='juliet@capulet.com/balcony' to='romeo@montague.net' id='msg-id-1'>");
		i.write("<body>Hello Romeo</body>");
		i.write("</message>");
		i.write("</forwarded>");
		i.write("</result>");
		i.write("</archive>");
		i.write("</user>");
		i.write("</host>");
		i.write("</server-data>");

		Assert.equals(1, items.length);
		final msg = items[0];
		Assert.equals("romeo@montague.net", msg.chatId);
		Assert.equals("juliet@capulet.com", msg.senderId);
		switch (msg.parsed) {
			case ChatMessageStanza(chatMsg):
				Assert.equals("Hello Romeo", chatMsg.body().toPlainText());
				Assert.equals("mam-id-1", chatMsg.serverId);
				Assert.equals("juliet@capulet.com", chatMsg.serverIdBy);
				Assert.equals("2023-10-27T10:00:00.001Z", chatMsg.timestamp);
				Assert.isFalse(chatMsg.isIncoming());
			default:
				Assert.fail("Expected ChatMessageStanza");
		}
	}

	public function testTargetAccount() {
		final items = [];

		final i = new Import("me@example.com");
		i.onMessage = (source, msg) -> {
			items.push(msg);
		};
		i.write("<server-data xmlns='urn:xmpp:pie:0'>");
		i.write("<host jid='capulet.com'>");
		i.write("<user name='juliet'>");
		i.write("<archive xmlns='urn:xmpp:pie:0#mam'>");
		i.write("<result xmlns='urn:xmpp:mam:2' id='mam-id-1'>");
		i.write("<forwarded xmlns='urn:xmpp:forward:0'>");
		i.write("<delay xmlns='urn:xmpp:delay' stamp='2023-10-27T10:00:00Z' />");
		i.write("<message xmlns='jabber:client' from='juliet@capulet.com/balcony' to='romeo@montague.net' id='msg-id-1'>");
		i.write("<body>Hello Romeo</body>");
		i.write("</message>");
		i.write("</forwarded>");
		i.write("</result>");
		i.write("</archive>");
		i.write("</user>");
		i.write("</host>");
		i.write("</server-data>");

		Assert.equals(1, items.length);
		final msg = items[0];
		Assert.equals("romeo@montague.net", msg.chatId);
		Assert.equals("me@example.com", msg.senderId);
		switch (msg.parsed) {
			case ChatMessageStanza(chatMsg):
				Assert.isFalse(chatMsg.isIncoming());
			default:
				Assert.fail("Expected ChatMessageStanza");
		}
	}

	public function testTimestampFixing() {
		final items = [];

		final i = new Import(null);
		i.onMessage = (source, msg) -> {
			items.push(msg);
		};
		i.write("<server-data xmlns='urn:xmpp:pie:0'>");
		i.write("<host jid='capulet.com'>");
		i.write("<user name='juliet'>");
		i.write("<archive xmlns='urn:xmpp:pie:0#mam'>");

		i.write("<result xmlns='urn:xmpp:mam:2' id='mam-id-1'>");
		i.write("<forwarded xmlns='urn:xmpp:forward:0'>");
		i.write("<delay xmlns='urn:xmpp:delay' stamp='2023-10-27T10:00:00Z' />");
		i.write("<message xmlns='jabber:client' from='juliet@capulet.com' to='romeo@montague.net' id='m1'><body>1</body></message>");
		i.write("</forwarded>");
		i.write("</result>");

		i.write("<result xmlns='urn:xmpp:mam:2' id='mam-id-2'>");
		i.write("<forwarded xmlns='urn:xmpp:forward:0'>");
		i.write("<delay xmlns='urn:xmpp:delay' stamp='2023-10-27T10:00:00Z' />");
		i.write("<message xmlns='jabber:client' from='juliet@capulet.com' to='romeo@montague.net' id='m2'><body>2</body></message>");
		i.write("</forwarded>");
		i.write("</result>");

		i.write("<result xmlns='urn:xmpp:mam:2' id='mam-id-3'>");
		i.write("<forwarded xmlns='urn:xmpp:forward:0'>");
		i.write("<delay xmlns='urn:xmpp:delay' stamp='2023-10-27T10:00:01Z' />");
		i.write("<message xmlns='jabber:client' from='juliet@capulet.com' to='romeo@montague.net' id='m3'><body>3</body></message>");
		i.write("</forwarded>");
		i.write("</result>");

		i.write("</archive>");
		i.write("</user>");
		i.write("</host>");
		i.write("</server-data>");

		Assert.equals(3, items.length);

		switch (items[0].parsed) {
			case ChatMessageStanza(m): Assert.equals("2023-10-27T10:00:00.001Z", m.timestamp);
			default: Assert.fail();
		}
		switch (items[1].parsed) {
			case ChatMessageStanza(m): Assert.equals("2023-10-27T10:00:00.002Z", m.timestamp);
			default: Assert.fail();
		}
		switch (items[2].parsed) {
			case ChatMessageStanza(m): Assert.equals("2023-10-27T10:00:01.001Z", m.timestamp);
			default: Assert.fail();
		}
	}
}
