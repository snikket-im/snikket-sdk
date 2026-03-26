package test;

import utest.Assert;
import borogove.Util;

class TestUtil extends utest.Test {
	public function testXmlEscape() {
		Assert.equals("foo &amp; bar &lt; baz &gt;", borogove.Util.xmlEscape("foo & bar < baz >"));
		Assert.equals("nothing", borogove.Util.xmlEscape("nothing"));
		Assert.equals("", borogove.Util.xmlEscape(""));
	}

	public function testUriDecode() {
		Assert.equals("a b", borogove.Util.uriDecode("a%20b"));
		Assert.equals("a+b", borogove.Util.uriDecode("a+b")); // Should NOT decode + as space
		Assert.equals("!", borogove.Util.uriDecode("%21"));
		Assert.equals("hello", borogove.Util.uriDecode("hello"));
	}

	public function testCapitalize() {
		Assert.equals("Hello", Util.capitalize("hello"));
		Assert.equals("Hello", Util.capitalize("Hello"));
		Assert.equals("A", Util.capitalize("a"));
		Assert.equals("", Util.capitalize(""));
		Assert.isNull(Util.capitalize(null));
	}

	public function testSearchHelpers() {
		final arr = [1, 2, 3, 4, 5];
		Assert.isTrue(borogove.Util.existsFast(arr, (x) -> x == 3));
		Assert.isFalse(borogove.Util.existsFast(arr, (x) -> x == 10));

		Assert.equals(4, borogove.Util.findFast(arr, (x) -> x > 3));
		Assert.isNull(borogove.Util.findFast(arr, (x) -> x > 10));
	}
}
