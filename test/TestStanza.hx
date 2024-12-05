package test;


import utest.Assert;
import utest.Async;
import snikket.Stanza;

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
}
