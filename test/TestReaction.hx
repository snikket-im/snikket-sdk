package test;

import utest.Assert;
import borogove.Reaction;

@:access(borogove.Reaction)
class TestReaction extends utest.Test {
	public function testNormalization() {
		// 👍 with variation selector 16 (\u{fe0f})
		var r = Reaction.unicode("👍\u{fe0f}");

		// Internal text should have it stripped
		Assert.equals("👍", r.text);

		// Render should add it back
		var rendered = r.render((text) -> text, (name, uri) -> "");
		Assert.equals("👍\u{fe0f}", rendered);
	}

	public function testCustomEmoji() {
		var r = CustomEmojiReaction.custom("tada", "https://example.com/tada.png");

		var rendered = r.render(
			(text) -> "text:" + text,
			(name, uri) -> "image:" + name + ":" + uri
		);

		Assert.equals("image:tada:https://example.com/tada.png", rendered);
	}
}
