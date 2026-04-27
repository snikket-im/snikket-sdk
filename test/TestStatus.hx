package test;

import utest.Assert;
import borogove.Status;
import borogove.Stanza;

class TestStatus extends utest.Test {
	public function testToString() {
		Assert.equals("", new Status("", "").toString());
		Assert.equals("😊", new Status("😊", "").toString());
		Assert.equals("feeling good", new Status("", "feeling good").toString());
		Assert.equals("😊 feeling good", new Status("😊", "feeling good").toString());
	}

	public function testToStanza() {
		final s1 = new Status("😊", "feeling good").toStanza();
		Assert.equals("activity", s1.name);
		Assert.equals("http://jabber.org/protocol/activity", s1.attr.get("xmlns"));
		Assert.equals("feeling good", s1.getChildText("text"));
		Assert.equals("😊", s1.getChild("undefined")?.getChildText("emoji", "https://ns.borogove.dev/"));

		final s2 = new Status("", "just text").toStanza();
		Assert.isNull(s2.getChild("undefined")?.getChildText("emoji", "https://ns.borogove.dev/"));
		Assert.equals("just text", s2.getChildText("text"));

		final s3 = new Status("🚀", "").toStanza();
		Assert.equals("🚀", s3.getChild("undefined")?.getChildText("emoji", "https://ns.borogove.dev/"));
		Assert.isNull(s3.getChildText("text"));
	}
}
