package test;

import utest.Assert;
import borogove.StringUtil;

class TestStringUtil extends utest.Test {
	public function testCodepointArray() {
		Assert.same(["a", "b", "c"], StringUtil.codepointArray("abc"));
		Assert.same(["👍", "!", "👋"], StringUtil.codepointArray("👍!👋"));
		Assert.same(["\u{1F601}", "\u{1F602}"], StringUtil.codepointArray("\u{1F601}\u{1F602}"));
		Assert.same([], StringUtil.codepointArray(""));
	}

	public function testRawCodepointArray() {
		Assert.same([97, 98, 99], StringUtil.rawCodepointArray("abc"));
		// 👍 is 0x1F44D (128077 decimal), 👋 is 0x1F44B (128075 decimal)
		Assert.same([128077, 33, 128075], StringUtil.rawCodepointArray("👍!👋"));
		Assert.same([], StringUtil.rawCodepointArray(""));
	}
}
