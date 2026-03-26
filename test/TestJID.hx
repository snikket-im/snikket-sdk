package test;

import utest.Assert;
import borogove.JID;

class TestJID extends utest.Test {
	public function testParse() {
		var jid = JID.parse("user@example.com");
		Assert.equals("user", jid.node);
		Assert.equals("example.com", jid.domain);
		Assert.isNull(jid.resource);

		jid = JID.parse("user@example.com/mobile");
		Assert.equals("user", jid.node);
		Assert.equals("example.com", jid.domain);
		Assert.equals("mobile", jid.resource);

		jid = JID.parse("example.com");
		Assert.isNull(jid.node);
		Assert.equals("example.com", jid.domain);
		Assert.isNull(jid.resource);

		jid = JID.parse("example.com/resource");
		Assert.isNull(jid.node);
		Assert.equals("example.com", jid.domain);
		Assert.equals("resource", jid.resource);
	}

	public function testEscape() {
		// Test that escaping works in constructor
		var jid = new JID("node with space", "example.com");
		Assert.equals("node\\20with\\20space", jid.node);
		Assert.equals("node\\20with\\20space@example.com", jid.asString());

		jid = new JID("d'artagnan", "example.com");
		Assert.equals("d\\27artagnan", jid.node);

		jid = new JID("alice@wonderland", "example.com");
		Assert.equals("alice\\40wonderland", jid.node);

		// Test parsing escaped JIDs
		jid = JID.parse("node\\20with\\20space@example.com");
		Assert.equals("node\\20with\\20space", jid.node);
	}

	public function testUtilityMethods() {
		var jid = new JID("user", "example.com", "resource", true);
		Assert.isFalse(jid.isBare());
		Assert.isFalse(jid.isDomain());
		Assert.isTrue(jid.isValid());

		var bare = jid.asBare();
		Assert.isTrue(bare.isBare());
		Assert.equals("user@example.com", bare.asString());

		var withNewResource = bare.withResource("new");
		Assert.equals("new", withNewResource.resource);
		Assert.equals("user@example.com/new", withNewResource.asString());

		var domainOnly = new JID(null, "example.com");
		Assert.isTrue(domainOnly.isDomain());
		Assert.isTrue(domainOnly.isBare());
		Assert.equals("example.com", domainOnly.asString());

		var invalid = new JID(null, "localhost");
		Assert.isFalse(invalid.isValid());
	}

	public function testEquals() {
		var jid1 = new JID("user", "example.com", "res", true);
		var jid2 = new JID("user", "example.com", "res", true);
		var jid3 = new JID("user", "example.com", "other", true);

		Assert.isTrue(jid1.equals(jid2));
		Assert.isFalse(jid1.equals(jid3));
	}
}
