package borogove;

import borogove.Autolink;
import borogove.Stanza;
using StringTools;
using borogove.Util;

class XEP0393 {
	public static function parse(styled: UnicodeString): Array<Stanza> {
		final blocks = [];
		while (styled.length > 0) {
			final result = parseBlock(styled);
			styled = result.rest;
			blocks.push(result.block);
		}
		return blocks;
	}

	public static function render(xhtml: Stanza, inPre = false, followNewline = true) {
		if (xhtml.name == "br") {
			return "\n";
		}

		if (xhtml.name == "img") {
			return xhtml.attr.get("alt") ?? "";
		}

		final s = new StringBuf();
		var endsWithNewline = true;

		if (!followNewline && ["blockquote", "pre", "div", "p"].contains(xhtml.name)) {
			s.add("\n");
			endsWithNewline = true;
		}

		if (xhtml.name == "pre") {
			final code = xhtml.getChild("code");
			var lang = "";
			if (code != null && xhtml.children.length == 1) {
				final className = code.attr.get("class") ?? "";
				if (className.startsWith("language-")) {
					lang = className.substr(9);
				}
			}
			s.add("```" + lang + "\n");
			endsWithNewline = true;
		}

		if (xhtml.name == "b" || xhtml.name == "strong") {
			s.add("*");
			endsWithNewline = false;
		}

		if (xhtml.name == "i" || xhtml.name == "em") {
			s.add("_");
			endsWithNewline = false;
		}

		if (xhtml.name == "s" || xhtml.name == "del") {
			s.add("~");
			endsWithNewline = false;
		}

		if (!inPre && (xhtml.name == "tt" || xhtml.name == "code")) {
			s.add("`");
			endsWithNewline = false;
		}

		for (child in xhtml.children) {
			final rendered = renderNode(child, xhtml.name == "pre", endsWithNewline);
			s.add(rendered);
			endsWithNewline = rendered.endsWith("\n");
		}

		if (xhtml.name == "b" || xhtml.name == "strong") {
			s.add("*");
			endsWithNewline = false;
		}

		if (xhtml.name == "i" || xhtml.name == "em") {
			s.add("_");
			endsWithNewline = false;
		}

		if (xhtml.name == "s" || xhtml.name == "del") {
			s.add("~");
			endsWithNewline = false;
		}

		if (!inPre && (xhtml.name == "tt" || xhtml.name == "code")) {
			s.add("`");
			endsWithNewline = false;
		}

		if (!endsWithNewline && ["blockquote", "pre", "div", "p"].contains(xhtml.name)) {
			s.add("\n");
			endsWithNewline = true;
		}

		if (xhtml.name == "pre") {
			s.add("```\n");
			endsWithNewline = true;
		}

		if (xhtml.name == "blockquote") {
			return ~/^/gm.replace(s.toString(), "> ");
		}

		return s.toString();
	}

	public static function renderNode(xhtml: Node, inPre = false, followNewline = true) {
		return switch (xhtml) {
			case Element(c): render(c, inPre, followNewline);
			case CData(c): c.content;
		};
	}

	public static function parseSpans(styled: UnicodeString) {
		final spans = [];
		var start = 0;
		var nextLink: Null<{ span: Null<Node>, start: Int, end: Int }> = null;
		final styledLength = styled.length;
		while (start < styledLength) {
			final char = styled.charAt(start);
			if (isSpace(styled, start + 1)) {
				// The opening styling directive MUST NOT be followed by a whitespace character
				spans.push(CData(new TextNode(styled.substr(start, 2))));
				start += 2;
			} else if (start != 0 && !isSpace(styled, start - 1)) {
				// The opening styling directive MUST be located at the beginning of the parent block, after a whitespace character, or after a different opening styling directive.
				spans.push(CData(new TextNode(char)));
				start++;
			} else if (char == "*") {
				final parsed = parseSpan("strong", "*", styled, start);
				spans.push(parsed.span);
				start = parsed.end;
			} else if (char == "_") {
				final parsed = parseSpan("em", "_", styled, start);
				spans.push(parsed.span);
				start = parsed.end;
			} else if (char == "~") {
				final parsed = parseSpan("s", "~", styled, start);
				spans.push(parsed.span);
				start = parsed.end;
			} else if (char == "`") {
				// parseSpan has a spcial case for us to not parse sub-spans
				final parsed = parseSpan("tt", "`", styled, start);
				spans.push(parsed.span);
				start = parsed.end;
			} else {
				if (nextLink == null || start > nextLink.start) {
					nextLink = Autolink.one(styled, start);
					if (nextLink != null) {
						nextLink.start = styled.convertIndex(nextLink.start);
						nextLink.end = styled.convertIndex(nextLink.end);
					}
				}
				if (nextLink != null && nextLink.start == start && nextLink.span != null) {
					spans.push(nextLink.span);
					start = nextLink.end;
				} else {
					spans.push(CData(new TextNode(char)));
					start++;
				}
			}
		}
		return mergeSpans(spans);
	}

	private static function mergeSpans(spans: Array<Node>) {
		final mergedSpans = [];
		for (span in spans) {
			if (mergedSpans.length > 0) {
				final last = mergedSpans[mergedSpans.length - 1];
				switch [last, span] {
					case [CData(l), CData(s)]:
						mergedSpans[mergedSpans.length - 1] = CData(new TextNode(l.content + s.content));
					case _:
						mergedSpans.push(span);
				}
			} else {
				mergedSpans.push(span);
			}
		}
		return mergedSpans;
	}

	public static function parseSpan(tagName: String, marker: String, styled: UnicodeString, start: Int) {
		var end = start + 1;
		while (end < styled.length && styled.charAt(end) != marker) {
			if (isSpace(styled, end)) end++; // the closing styling directive MUST NOT be preceeded by a whitespace character
			end++;
		}
		if (end == start + 1) {
			// Matches of spans between two styling directives MUST contain some text between the two directives, otherwise neither directive is valid
			return { span: CData(new TextNode(styled.substr(start, 2))), end: end + 1 };
		} else if (styled.charAt(end) != marker) {
			// No end marker, so not a span
			return { span: CData(new TextNode(styled.substr(start, end - start))), end: end };
		} else if (marker == "`") {
			return { span: Element(new Stanza(tagName).text(styled.substr(start + 1, (end - start - 1)))), end: end + 1 };
		} else {
			return { span: Element(new Stanza(tagName).addChildNodes(parseSpans(styled.substr(start + 1, (end - start - 1))))), end: end + 1 };
		}
	}

	public static function parseBlock(styled: UnicodeString) {
		if (styled.charAt(0) == ">") {
			return parseQuote(styled);
		} else if (styled.substr(0, 3) == "```") {
			return parsePreformatted(styled);
		} else {
			var end = 0;
			final styledLength = styled.length;
			while (end < styledLength && styled.charAt(end) != "\n") end++;
			final lineEnd = end;
			if (end < styledLength && styled.charAt(end) == "\n") end++;
			return { block: new Stanza("div").addChildNodes(parseSpans(styled.substr(0, lineEnd))), rest: styled.substr(end) };
		}
	}

	public static function parseQuote(styled: UnicodeString) {
		final lines = [];
		var line = "";
		var end = 1; // Skip leading >
		var spaceAfter = 0;
		while (end < styled.length) {
			if (styled.charAt(end) != "\n" && isSpace(styled, end)) end++;
			while (end < styled.length && styled.charAt(end) != "\n") {
				line += styled.charAt(end);
				end++;
			}
			if (end < styled.length && styled.charAt(end) == "\n") {
				end++;
			}
			lines.push(line+"\n");
			line = "";
			if (styled.charAt(end) == ">") {
				end++;
			} else {
				break;
			}
		}

		return { block: new Stanza("blockquote").addChildren(parse(lines.join(""))), rest: styled.substr(end) };
	}


	public static function parsePreformatted(styled: UnicodeString) {
		final lines = [];
		var line = "";
		var lang = null;
		var end = 0;
		final styledLength = styled.length;
		while (end < styledLength) {
			while (end < styledLength && styled.charAt(end) != "\n") {
				line += styled.charAt(end);
				end++;
			}
			if (end < styledLength && styled.charAt(end) == "\n") {
				end++;
			}

			if (lang == null) {
				lang = line.substr(3).trim();
			} else {
				lines.push(line + "\n");
			}
			line = "";

			if (styled.substr(end, 4) == "```\n" || styled.substr(end) == "```") {
				end += 4;
				break;
			}
		}

		final block = new Stanza("pre");
		if (lang != "") {
			block.tag("code", {"class": 'language-$lang'}).text(lines.join(""));
		} else {
			block.text(lines.join(""));
		}

		return { block: block, rest: styled.substr(end) };
	}

	private static function isSpace(s: UnicodeString, pos: Int) {
		// The version in StringTools won't use UnicodeString-aware indices
		return s.charAt(pos).isSpace(0);
	}
}
