package test;

import utest.Assert;
import utest.Async;
import borogove.XEP0393;

class TestXEP0393 extends utest.Test {
	function toHtml(s: String) {
		return XEP0393.parse(s).map(b -> b.toString()).join("");
	}

	public function testSpansDoNotEscapeBlocks() {
		Assert.equals(
			"<div>There are three blocks in this body, one per line,
</div><div>but there is no *formatting
</div><div>as spans* may not escape blocks.</div>",
			toHtml("There are three blocks in this body, one per line,
but there is no *formatting
as spans* may not escape blocks.")
		);
	}

	public function testPreformattedBlock() {
		Assert.equals(
			"<pre>(println \"Hello, world!\")
</pre><div>
</div><div>This should show up as monospace, preformatted text ⤴</div>",
			toHtml("```ignored
(println \"Hello, world!\")
```

This should show up as monospace, preformatted text ⤴")
		);
	}

	public function testPreformattedBlockUnterminated() {
		Assert.equals(
			"<blockquote><pre>(println \"Hello, world!\")
</pre></blockquote><div>
</div><div>The entire blockquote is a preformatted text block, but this line
</div><div>is plaintext!</div>",
			toHtml("> ```ignored
> (println \"Hello, world!\")

The entire blockquote is a preformatted text block, but this line
is plaintext!")
		);
	}

	public function testQuotation() {
		Assert.equals(
			"<blockquote><div>That that is, is.
</div></blockquote><div>
</div><div>Said the old hermit of Prague.</div>",
			toHtml("> That that is, is.

Said the old hermit of Prague.")
		);
	}

	public function testNestedQuotation() {
		Assert.equals(
			"<blockquote><blockquote><div>That that is, is.
</div></blockquote><div>Said the old hermit of Prague.
</div></blockquote><div>
</div><div>Who?</div>",
			toHtml(">> That that is, is.
> Said the old hermit of Prague.

Who?")
		);
	}

	public function testPlainSpan() {
		Assert.equals(
			"<div>plain span</div>",
			toHtml("plain span")
		);
	}

	public function testStrongSpan() {
		Assert.equals(
			"<div><strong>strong span</strong></div>",
			toHtml("*strong span*")
		);
	}

	public function testPlainEmphasisPlain() {
		Assert.equals(
			"<div>plain <em>emphasis</em> plain</div>",
			toHtml("plain _emphasis_ plain")
		);
	}

	public function testPrePlainStrong() {
		Assert.equals(
			"<div><tt>pre</tt> plain <strong>strong</strong></div>",
			toHtml("`pre` plain *strong*")
		);
	}

	public function testStrongPlain() {
		Assert.equals(
			"<div><strong>strong</strong>plain*</div>",
			toHtml("*strong*plain*")
		);
	}

	public function testPlainStrong() {
		Assert.equals(
			"<div>* plain <strong>strong</strong></div>",
			toHtml("* plain *strong*")
		);
	}

	public function testNotStrong1() {
		Assert.equals(
			"<div>not strong*</div>",
			toHtml("not strong*")
		);
	}

	public function testNotStrong2() {
		Assert.equals(
			"<div>*not strong</div>",
			toHtml("*not strong")
		);
	}

	public function testNotStrong3() {
		Assert.equals(
			"<div>*not \n</div><div> strong</div>",
			toHtml("*not \n strong")
		);
	}

	public function testNotStrong4() {
		Assert.equals(
			"<div>**</div>",
			toHtml("**")
		);
	}

	public function testNotStrong5() {
		Assert.equals(
			"<div>***</div>",
			toHtml("***")
		);
	}

	public function testNotStrong6() {
		Assert.equals(
			"<div>****</div>",
			toHtml("****")
		);
	}

	public function testStrike() {
		Assert.equals(
			"<div>Everyone <s>dis</s>likes cake.</div>",
			toHtml("Everyone ~dis~likes cake.")
		);
	}

	public function testThisIsMonospace() {
		Assert.equals(
			"<div>This is <tt>*monospace*</tt></div>",
			toHtml("This is `*monospace*`")
		);
	}

	public function testThisIsMonospaceAndBold() {
		Assert.equals(
			"<div>This is <strong><tt>monospace and bold</tt></strong></div>",
			toHtml("This is *`monospace and bold`*")
		);
	}

	// NOTE: autolink is not part of the XEP, but we process it within blocks
	// for consistency with the rest of the XEP rules

	public function testAutolink() {
		Assert.equals(
			"<blockquote><div><a href=\"https://example.com\">example.com</a>
</div></blockquote>",
			toHtml("> example.com")
		);
	}

	public function testNoAutolink() {
		Assert.equals(
			"<div><tt>example.com</tt></div>",
			toHtml("`example.com`")
		);
	}

	public function testAutolinkXMPP() {
		Assert.equals(
			"<div>hello <a href=\"xmpp:alice@example.com\">xmpp:alice@example.com</a></div>",
			toHtml("hello xmpp:alice@example.com")
		);
	}

	public function testAutolinkAfterEmoji() {
		Assert.equals(
			"<div>📞 icon <a href=\"https://example.com\">example.com</a></div>",
			toHtml("📞 icon example.com")
		);
	}
}
