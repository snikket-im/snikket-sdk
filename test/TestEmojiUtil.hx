package test;

import utest.Assert;
import borogove.EmojiUtil;

class TestEmojiUtil extends utest.Test {
	public function testDoubleExclamationMark() {
		Assert.isFalse(EmojiUtil.isEmoji("‼"));
		Assert.isTrue(EmojiUtil.isEmoji("‼️"));
	}

	public function testInterrobang() {
		Assert.isFalse(EmojiUtil.isEmoji("⁉"));
		Assert.isTrue(EmojiUtil.isEmoji("⁉️"));
	}

	public function testArrows() {
		Assert.isFalse(EmojiUtil.isEmoji("↔"));
		Assert.isTrue(EmojiUtil.isEmoji("↔️"));
	}

	public function testCopyright() {
		Assert.isFalse(EmojiUtil.isEmoji("©"));
		Assert.isTrue(EmojiUtil.isEmoji("©️"));
	}

	public function testStar() {
		Assert.isFalse(EmojiUtil.isEmoji("⭐"));
		Assert.isTrue(EmojiUtil.isEmoji("⭐️"));
	}

	public function testRegularEmoji() {
		Assert.isTrue(EmojiUtil.isEmoji("😀"));
		Assert.isTrue(EmojiUtil.isEmoji("🚀"));
	}

	public function testIsOnlyEmoji() {
		Assert.isTrue(EmojiUtil.isOnlyEmoji("‼️😀🚀"));
		Assert.isFalse(EmojiUtil.isOnlyEmoji("‼️ a"));
		Assert.isFalse(EmojiUtil.isOnlyEmoji("‼"));
	}
}
