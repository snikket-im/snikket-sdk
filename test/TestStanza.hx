package test;

import utest.Assert;
import utest.Async;
import borogove.Stanza;

@:access(borogove.Stanza)
class TestStanza extends utest.Test {
	public function testRemoveChildren() {
		final s = new Stanza("test", { xmlns: "urn:example:foo" })
			.textTag("odd", "")
			.textTag("even", "")
			.textTag("odd", "")
			.textTag("even", "");

		s.removeChildren("odd");

		var count = 0;
		for(tag in s.allTags()) {
			count++;
			Assert.equals("even", tag.name);
		}
		Assert.equals(2, count);
	}

	public function testParseXmlBool() {
		Assert.equals(true, Stanza.parseXmlBool("true"));
		Assert.equals(true, Stanza.parseXmlBool("1"));
		Assert.equals(false, Stanza.parseXmlBool("false"));
		Assert.equals(false, Stanza.parseXmlBool("0"));
	}

	public function testFluentApi() {
		final s = new Stanza("root")
			.tag("child", { id: "1" })
				.text("hello")
				.up()
			.tag("child", { id: "2" })
				.tag("grandchild")
					.text("world")
				.up()
			.up();

		Assert.equals(2, s.allTags("child").length);
		var secondChild = s.allTags("child")[1];
		Assert.equals("2", secondChild.attr.get("id"));
		Assert.equals("world", secondChild.getChildText("grandchild"));
	}

	public function testFind() {
		final s = new Stanza("root")
			.tag("person", { name: "Alice" })
				.textTag("email", "alice@example.com")
				.up()
			.tag("person", { name: "Bob" })
				.textTag("email", "bob@example.com")
				.up();

		Assert.equals("Alice", s.findText("person@name"));
		Assert.equals("alice@example.com", s.findText("person/email#"));

		var person = s.findChild("person");
		Assert.equals("Alice", person.attr.get("name"));
	}

	public function testClone() {
		final s = new Stanza("root")
			.tag("child")
				.text("original")
			.up();

		final cloned = s.clone();
		Assert.equals(s.serialize(), cloned.serialize());

		// Modify original
		s.allTags("child")[0].children = [];
		s.allTags("child")[0].text("modified");

		Assert.equals("modified", s.getChildText("child"));
		Assert.equals("original", cloned.getChildText("child"));
	}
}
