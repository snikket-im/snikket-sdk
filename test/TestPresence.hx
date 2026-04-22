package test;

import utest.Assert;

import borogove.Presence;
import borogove.Stanza;
import borogove.Caps;
import borogove.Hash;
import borogove.MucUser;

class TestPresence extends utest.Test {
	public function testFromStanza() {
		final stanza = Stanza.parse('<presence from="user@example.com/res">
			<c xmlns="http://jabber.org/protocol/caps" node="http://example.com" ver="12345"/>
			<x xmlns="http://jabber.org/protocol/muc#user"><item affiliation="member" role="participant"/></x>
			<x xmlns="vcard-temp:x:update"><photo>deadbeef</photo></x>
		</presence>');
		final presence: Presence = stanza;

		Assert.equals("http://example.com", presence.capsNode);
		Assert.equals("12345", presence.ver);
		Assert.notNull(presence.mucUser);
		Assert.equals("deadbeef", presence.avatarHash.toHex());
	}

	public function testNew() {
		final caps = new Caps("http://example.com", [], [], []);
		final presence = new Presence(caps, null, Hash.fromHex("sha-1", "deadbeef"));

		Assert.equals("http://example.com", presence.capsNode);
		Assert.equals(caps.ver(), presence.ver);
		Assert.isNull(presence.mucUser);
		Assert.equals("deadbeef", presence.avatarHash.toHex());

		Assert.stringContains('xmlns="vcard-temp:x:update"', presence.toString());
		Assert.stringContains("<photo>deadbeef</photo>", presence.toString());
	}

	public function testNoCaps() {
		final stanza = Stanza.parse('<presence/>');
		final presence: Presence = stanza;
		Assert.isNull(presence.capsNode);
		Assert.isNull(presence.ver);
	}
}
