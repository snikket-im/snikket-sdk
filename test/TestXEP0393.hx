package test;

import utest.Assert;
import utest.Async;

import borogove.Stanza;
import borogove.XEP0393;

class TestXEP0393 extends utest.Test {
	function toHtml(s: String) {
		return XEP0393.parse(s).map(b -> b.toString()).join("");
	}

	public function testSpansDoNotEscapeBlocks() {
		Assert.equals(
			"<p>There are three blocks in this body, one per line,<br/>but there is no *formatting<br/>as spans* may not escape blocks.</p>",
			toHtml("There are three blocks in this body, one per line,
but there is no *formatting
as spans* may not escape blocks.")
		);
	}

	public function testPreformattedBlockSimple() {
		Assert.equals(
			"<pre>(println \"Hello, world!\")
</pre><p>This should show up as monospace, preformatted text ⤴</p>",
			toHtml("```
(println \"Hello, world!\")
```

This should show up as monospace, preformatted text ⤴")
		);
	}

	public function testPreformattedBlock() {
		Assert.equals(
			"<pre><code class=\"language-ignored\">(println \"Hello, world!\")
</code></pre><p>This should show up as monospace, preformatted text ⤴</p>",
			toHtml("```ignored
(println \"Hello, world!\")
```

This should show up as monospace, preformatted text ⤴")
		);
	}

	public function testPreformattedBlockUnterminated() {
		Assert.equals(
			"<blockquote><pre><code class=\"language-ignored\">(println \"Hello, world!\")
</code></pre></blockquote><p>The entire blockquote is a preformatted text block, but this line<br/>is plaintext!</p>",
			toHtml("> ```ignored
> (println \"Hello, world!\")

The entire blockquote is a preformatted text block, but this line
is plaintext!")
		);
	}

	public function testQuotation() {
		Assert.equals(
			"<blockquote><p>That that is, is.</p></blockquote><p>Said the old hermit of Prague.</p>",
			toHtml("> That that is, is.

Said the old hermit of Prague.")
		);
	}

	public function testNestedQuotation() {
		Assert.equals(
			"<blockquote><blockquote><p>That that is, is.</p></blockquote><p>Said the old hermit of Prague.</p></blockquote><p>Who?</p>",
			toHtml(">> That that is, is.
> Said the old hermit of Prague.

Who?")
		);
	}

	public function testQuotationAfterPlain() {
		Assert.equals(
			"<p class=\"tight\">He said:</p><blockquote><p>What is up</p></blockquote>",
			toHtml("He said:
> What is up")
		);
	}

	public function testCodeAfterPlain() {
		Assert.equals(
			"<p class=\"tight\">He said:</p><pre>some code
</pre>",
			toHtml("He said:
```
some code")
		);
	}

	public function testQuotationAfterPlainPara() {
		Assert.equals(
			"<p>He said:</p><blockquote><p>What is up</p></blockquote>",
			toHtml("He said:

> What is up")
		);
	}

	public function testPlainSpan() {
		Assert.equals(
			"<p>plain span</p>",
			toHtml("plain span")
		);
	}

	public function testPlainSpanOneCdata() {
		final node = XEP0393.parse("plain span")[0].children[0];
		switch (node) {
			case CData(t):
				Assert.equals("plain span", t.content);
			case _:
				Assert.fail("Expected CData, but got " + node);
		}
	}

	public function testMergedWithElement() {
		final children = XEP0393.parse("plain *bold* plain")[0].children;
		Assert.equals(3, children.length);
		switch (children[0]) {
			case CData(t): Assert.equals("plain ", t.content);
			case _: Assert.fail("Expected CData");
		}
		switch (children[1]) {
			case Element(s): Assert.equals("strong", s.name);
			case _: Assert.fail("Expected Element");
		}
		switch (children[2]) {
			case CData(t): Assert.equals(" plain", t.content);
			case _: Assert.fail("Expected CData");
		}
	}

	public function testStrongSpan() {
		Assert.equals(
			"<p><strong>strong span</strong></p>",
			toHtml("*strong span*")
		);
	}

	public function testPlainEmphasisPlain() {
		Assert.equals(
			"<p>plain <em>emphasis</em> plain</p>",
			toHtml("plain _emphasis_ plain")
		);
	}

	public function testPrePlainStrong() {
		Assert.equals(
			"<p><tt>pre</tt> plain <strong>strong</strong></p>",
			toHtml("`pre` plain *strong*")
		);
	}

	public function testStrongPlain() {
		Assert.equals(
			"<p><strong>strong</strong>plain*</p>",
			toHtml("*strong*plain*")
		);
	}

	public function testPlainStrong() {
		Assert.equals(
			"<p>* plain <strong>strong</strong></p>",
			toHtml("* plain *strong*")
		);
	}

	public function testNotStrong1() {
		Assert.equals(
			"<p>not strong*</p>",
			toHtml("not strong*")
		);
	}

	public function testNotStrong2() {
		Assert.equals(
			"<p>*not strong</p>",
			toHtml("*not strong")
		);
	}

	public function testNotStrong3() {
		Assert.equals(
			"<p>*not <br/> strong</p>",
			toHtml("*not \n strong")
		);
	}

	public function testNotStrong4() {
		Assert.equals(
			"<p>**</p>",
			toHtml("**")
		);
	}

	public function testNotStrong5() {
		Assert.equals(
			"<p>***</p>",
			toHtml("***")
		);
	}

	public function testNotStrong6() {
		Assert.equals(
			"<p>****</p>",
			toHtml("****")
		);
	}

	public function testStrike() {
		Assert.equals(
			"<p>Everyone <s>dis</s>likes cake.</p>",
			toHtml("Everyone ~dis~likes cake.")
		);
	}

	public function testThisIsMonospace() {
		Assert.equals(
			"<p>This is <tt>*monospace*</tt></p>",
			toHtml("This is `*monospace*`")
		);
	}

	public function testThisIsMonospaceAndBold() {
		Assert.equals(
			"<p>This is <strong><tt>monospace and bold</tt></strong></p>",
			toHtml("This is *`monospace and bold`*")
		);
	}

	// NOTE: autolink is not part of the XEP, but we process it within blocks
	// for consistency with the rest of the XEP rules

	public function testAutolink() {
		Assert.equals(
			"<blockquote><p><a href=\"https://example.com\">example.com</a></p></blockquote>",
			toHtml("> example.com")
		);
	}

	public function testNoAutolink() {
		Assert.equals(
			"<p><tt>example.com</tt></p>",
			toHtml("`example.com`")
		);
	}

	public function testAutolinkXMPP() {
		Assert.equals(
			"<p>hello <a href=\"xmpp:alice@example.com\">xmpp:alice@example.com</a></p>",
			toHtml("hello xmpp:alice@example.com")
		);
	}

	public function testAutolinkXMPPQueryString() {
		Assert.equals(
			"<p>hello <a href=\"xmpp:alice@example.com?;a=b\">xmpp:alice@example.com?;a=b</a></p>",
			toHtml("hello xmpp:alice@example.com?;a=b")
		);
	}

	public function testAutolinkTel() {
		Assert.equals(
			"<p>hello <a href=\"tel:+15551234567\">tel:+15551234567</a></p>",
			toHtml("hello tel:+15551234567")
		);
	}

	public function testAutolinkSms() {
		Assert.equals(
			"<p>hello <a href=\"sms:+15551234567\">sms:+15551234567</a></p>",
			toHtml("hello sms:+15551234567")
		);
	}

	public function testAutolinkMailto() {
		Assert.equals(
			"<p>hello <a href=\"mailto:alice@example.com\">mailto:alice@example.com</a></p>",
			toHtml("hello mailto:alice@example.com")
		);
	}

	public function testAutolinkMailtoQueryString() {
		Assert.equals(
			"<p>hello <a href=\"mailto:alice@example.com?subject=Hi\">mailto:alice@example.com?subject=Hi</a></p>",
			toHtml("hello mailto:alice@example.com?subject=Hi")
		);
	}

	public function testAutolinkEmail() {
		Assert.equals(
			"<p>hello <a href=\"mailto:alice@example.com\">alice@example.com</a></p>",
			toHtml("hello alice@example.com")
		);
	}

	public function testAutolinkAfterEmoji() {
		Assert.equals(
			"<p>📞 icon <a href=\"https://example.com\">example.com</a></p>",
			toHtml("📞 icon example.com")
		);
	}

	public function testAutolinkNoTrailingSlash() {
		Assert.equals(
			"<p><a href=\"https://example.com/test/\">https://example.com/test/</a> a</p>",
			toHtml("https://example.com/test/ a")
		);
	}

	public function testAutolinkBareDomain() {
		Assert.equals(
			"<p><a href=\"https://example.com\">example.com</a></p>",
			toHtml("example.com")
		);
	}

	public function testAutolinkNoTrailingHash() {
		Assert.equals(
			"<p><a href=\"https://example.com/test#\">https://example.com/test#</a> a</p>",
			toHtml("https://example.com/test# a")
		);
	}

	public function testAutolinkTrailingDot() {
		Assert.equals(
			"<p><a href=\"https://example.com/test\">https://example.com/test</a>.</p>",
			toHtml("https://example.com/test.")
		);
	}

	public function testAutolinkTrailingParen() {
		Assert.equals(
			"<p><a href=\"https://example.com/test\">https://example.com/test</a>)</p>",
			toHtml("https://example.com/test)")
		);
	}

	public function testAutolinkBeaks() {
		Assert.equals(
			"<p>&lt;<a href=\"https://example.com/test\">https://example.com/test</a>&gt;</p>",
			toHtml("<https://example.com/test>")
		);
	}
}
