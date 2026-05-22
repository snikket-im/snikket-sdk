package test;

import utest.Assert;
import utest.Async;

import borogove.Caps;
import borogove.Hash;
import borogove.Stanza;
import borogove.queries.DiscoInfoGet;

@:access(borogove.Caps)
@:access(borogove.Hash.sha256)
class TestCaps extends utest.Test {
	final example = '
	<iq><query xmlns="http://jabber.org/protocol/disco#info" node="somenode">
		<identity category="client" name="Tkabber" type="pc" xml:lang="en"/>
		<identity category="client" name="Ткаббер" type="pc" xml:lang="ru"/>
		<feature var="games:board"/>
		<feature var="http://jabber.org/protocol/activity"/>
		<feature var="http://jabber.org/protocol/activity+notify"/>
		<feature var="http://jabber.org/protocol/bytestreams"/>
		<feature var="http://jabber.org/protocol/chatstates"/>
		<feature var="http://jabber.org/protocol/commands"/>
		<feature var="http://jabber.org/protocol/disco#info"/>
		<feature var="http://jabber.org/protocol/disco#items"/>
		<feature var="http://jabber.org/protocol/evil"/>
		<feature var="http://jabber.org/protocol/feature-neg"/>
		<feature var="http://jabber.org/protocol/geoloc"/>
		<feature var="http://jabber.org/protocol/geoloc+notify"/>
		<feature var="http://jabber.org/protocol/ibb"/>
		<feature var="http://jabber.org/protocol/iqibb"/>
		<feature var="http://jabber.org/protocol/mood"/>
		<feature var="http://jabber.org/protocol/mood+notify"/>
		<feature var="http://jabber.org/protocol/rosterx"/>
		<feature var="http://jabber.org/protocol/si"/>
		<feature var="http://jabber.org/protocol/si/profile/file-transfer"/>
		<feature var="http://jabber.org/protocol/tune"/>
		<feature var="http://www.facebook.com/xmpp/messages"/>
		<feature var="http://www.xmpp.org/extensions/xep-0084.html#ns-metadata+notify"/>
		<feature var="jabber:iq:avatar"/>
		<feature var="jabber:iq:browse"/>
		<feature var="jabber:iq:dtcp"/>
		<feature var="jabber:iq:filexfer"/>
		<feature var="jabber:iq:ibb"/>
		<feature var="jabber:iq:inband"/>
		<feature var="jabber:iq:jidlink"/>
		<feature var="jabber:iq:last"/>
		<feature var="jabber:iq:oob"/>
		<feature var="jabber:iq:privacy"/>
		<feature var="jabber:iq:roster"/>
		<feature var="jabber:iq:time"/>
		<feature var="jabber:iq:version"/>
		<feature var="jabber:x:data"/>
		<feature var="jabber:x:event"/>
		<feature var="jabber:x:oob"/>
		<feature var="urn:xmpp:avatar:metadata+notify"/>
		<feature var="urn:xmpp:ping"/>
		<feature var="urn:xmpp:receipts"/>
		<feature var="urn:xmpp:time"/>
		<x xmlns="jabber:x:data" type="result">
				<field type="hidden" var="FORM_TYPE">
						<value>urn:xmpp:dataforms:softwareinfo</value>
				</field>
				<field var="software">
						<value>Tkabber</value>
				</field>
				<field var="software_version">
						<value>0.11.1-svn-20111216-mod (Tcl/Tk 8.6b2)</value>
				</field>
				<field var="os">
						<value>Windows</value>
				</field>
				<field var="os_version">
						<value>XP</value>
				</field>
		</x>
	</query></iq>
	';

	public function caps(): Caps {
		final dig = new DiscoInfoGet("");
		dig.handleResponse(Stanza.parse(example));
		return dig.getResult();
	}

	public function testCaps2() {
		final sha256 = Hash.sha256(caps().hashInput()).toBase64();
		Assert.equals("u79ZroNJbdSWhdSp311mddz44oHHPsEBntQ5b1jqBSY=", sha256);
	}

	public function testCaps1() {
		final sha1 = caps().ver();
		Assert.equals("cePxJUNNZuDoNDbCMqs2VNEcJeY=", sha1);
	}

	public function testRoundTrip() {
		final dig = new DiscoInfoGet("");
		final iq = new Stanza("iq");
		iq.addChild(caps().discoReply());
		dig.handleResponse(iq);
		final sha256 = Hash.sha256(dig.getResult().hashInput()).toBase64();
		Assert.equals("u79ZroNJbdSWhdSp311mddz44oHHPsEBntQ5b1jqBSY=", sha256);
	}

	public function testAddC() {
		final s = new Stanza("presence");
		caps().addC(s);
		Assert.equals(
			'<presence><c xmlns="http://jabber.org/protocol/caps" ver="cePxJUNNZuDoNDbCMqs2VNEcJeY=" node="somenode" hash="sha-1"/><c xmlns="urn:xmpp:caps"><hash xmlns="urn:xmpp:hashes:2" algo="sha-256">u79ZroNJbdSWhdSp311mddz44oHHPsEBntQ5b1jqBSY=</hash></c></presence>',
			s.toString()
		);
	}

	public function testAddCEmpty() {
		final s = new Stanza("presence");
		final emptyCaps = new Caps("node1", [], [], []);
		emptyCaps.addC(s);
		Assert.equals(
			'<presence><c xmlns="http://jabber.org/protocol/caps" ver="2jmj7l5rSw0yVb/vlWAYkK/YBwk=" node="node1" hash="sha-1"/></presence>',
			s.toString()
		);
	}

	function stableKVOrderIterator<K, V>(data:Array<{key:K, value:V}>):KeyValueIterator<K, V> {
		var i = 0;
		return {
			hasNext: () -> i < data.length,
			next: () -> data[i++]
		};
	}

	public function testWithIdentityCategory() {
		final c1 = new Caps("n1", [new Identity("client", "pc", "test")], [], []);
		final c2 = new Caps("n2", [new Identity("gateway", "sms", "test")], [], []);
		final data = [{key: "r1", value: c1}, {key: "r2", value: c2}];

		var iter = Caps.withIdentity(stableKVOrderIterator(data), "client", null);
		Assert.isTrue(iter.hasNext());
		Assert.equals("r1", iter.next().key);
		Assert.isFalse(iter.hasNext());
	}

	public function testWithIdentityType() {
		final c1 = new Caps("n1", [new Identity("client", "pc", "test")], [], []);
		final c2 = new Caps("n2", [new Identity("gateway", "sms", "test")], [], []);
		final data = [{key: "r1", value: c1}, {key: "r2", value: c2}];

		var iter = Caps.withIdentity(stableKVOrderIterator(data), null, "sms");
		Assert.isTrue(iter.hasNext());
		Assert.equals("r2", iter.next().key);
		Assert.isFalse(iter.hasNext());
	}

	public function testWithIdentityBoth() {
		final c1 = new Caps("n1", [new Identity("client", "pc", "test")], [], []);
		final c2 = new Caps("n2", [new Identity("gateway", "sms", "test")], [], []);
		final data = [{key: "r1", value: c1}, {key: "r2", value: c2}];

		var iter = Caps.withIdentity(stableKVOrderIterator(data), "client", "pc");
		Assert.isTrue(iter.hasNext());
		Assert.equals("r1", iter.next().key);
		Assert.isFalse(iter.hasNext());
	}

	public function testWithIdentityNoMatch() {
		final c1 = new Caps("n1", [new Identity("client", "pc", "test")], [], []);
		final c2 = new Caps("n2", [new Identity("gateway", "sms", "test")], [], []);
		final data = [{key: "r1", value: c1}, {key: "r2", value: c2}];

		var iter = Caps.withIdentity(stableKVOrderIterator(data), "client", "sms");
		Assert.isFalse(iter.hasNext());

		iter = Caps.withIdentity(stableKVOrderIterator(data), "other", null);
		Assert.isFalse(iter.hasNext());
	}

	public function testWithIdentityEmpty() {
		var iter = Caps.withIdentity(stableKVOrderIterator([]), "client", null);
		Assert.isFalse(iter.hasNext());
	}

	public function testWithIdentityMatchLast() {
		final c1 = new Caps("n1", [new Identity("client", "pc", "test")], [], []);
		final c2 = new Caps("n2", [new Identity("gateway", "sms", "test")], [], []);
		final data = [{key: "r1", value: c1}, {key: "r2", value: c2}];

		var iter = Caps.withIdentity(stableKVOrderIterator(data), "gateway", null);
		Assert.isTrue(iter.hasNext());
		Assert.equals("r2", iter.next().key);
		Assert.isFalse(iter.hasNext());
	}

	public function testWithIdentityMatchMiddle() {
		final c1 = new Caps("n1", [new Identity("client", "pc", "test")], [], []);
		final c2 = new Caps("n2", [new Identity("gateway", "sms", "test")], [], []);
		final data = [{key: "r1", value: c2}, {key: "r2", value: c1}, {key: "r3", value: c2}];

		var iter = Caps.withIdentity(stableKVOrderIterator(data), "client", null);
		Assert.isTrue(iter.hasNext());
		Assert.equals("r2", iter.next().key);
		Assert.isFalse(iter.hasNext());
	}

	public function testWithFeatureMatch() {
		final c1 = new Caps("n1", [], ["f1", "f2"], []);
		final c2 = new Caps("n2", [], ["f2", "f3"], []);
		final data = [{key: "r1", value: c1}, {key: "r2", value: c2}];

		var iter = Caps.withFeature(stableKVOrderIterator(data), "f1");
		Assert.isTrue(iter.hasNext());
		Assert.equals("r1", iter.next().key);
		Assert.isFalse(iter.hasNext());
	}

	public function testWithFeatureMultiMatch() {
		final c1 = new Caps("n1", [], ["f1", "f2"], []);
		final c2 = new Caps("n2", [], ["f2", "f3"], []);
		final data = [{key: "r1", value: c1}, {key: "r2", value: c2}];

		var iter = Caps.withFeature(stableKVOrderIterator(data), "f2");
		Assert.isTrue(iter.hasNext());
		Assert.equals("r1", iter.next().key);
		Assert.isTrue(iter.hasNext());
		Assert.equals("r2", iter.next().key);
		Assert.isFalse(iter.hasNext());
	}

	public function testWithFeatureNoMatch() {
		final c1 = new Caps("n1", [], ["f1", "f2"], []);
		final c2 = new Caps("n2", [], ["f2", "f3"], []);
		final data = [{key: "r1", value: c1}, {key: "r2", value: c2}];

		var iter = Caps.withFeature(stableKVOrderIterator(data), "f4");
		Assert.isFalse(iter.hasNext());
	}

	public function testWithFeatureEmpty() {
		var iter = Caps.withFeature(stableKVOrderIterator([]), "f1");
		Assert.isFalse(iter.hasNext());
	}

	public function testWithFeatureMatchLast() {
		final c1 = new Caps("n1", [], ["f1", "f2"], []);
		final c2 = new Caps("n2", [], ["f2", "f3"], []);
		final data = [{key: "r1", value: c1}, {key: "r2", value: c2}];

		var iter = Caps.withFeature(stableKVOrderIterator(data), "f3");
		Assert.isTrue(iter.hasNext());
		Assert.equals("r2", iter.next().key);
		Assert.isFalse(iter.hasNext());
	}

	public function testWithFeatureMatchMiddle() {
		final c1 = new Caps("n1", [], ["f1", "f2"], []);
		final c2 = new Caps("n2", [], ["f2", "f3"], []);
		final data = [{key: "r1", value: c2}, {key: "r2", value: c1}, {key: "r3", value: c2}];

		var iter = Caps.withFeature(stableKVOrderIterator(data), "f1");
		Assert.isTrue(iter.hasNext());
		Assert.equals("r2", iter.next().key);
		Assert.isFalse(iter.hasNext());
	}
}
