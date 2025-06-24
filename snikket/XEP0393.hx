package snikket;

import snikket.Autolink;
import snikket.Stanza;

class XEP0393 {
	public static function parse(styled: UnicodeString) {
		final blocks = [];
		while (styled.length > 0) {
			final result = parseBlock(styled);
			styled = result.rest;
			blocks.push(result.block);
		}
		return blocks;
	}

	public static function render(xhtml: Stanza) {
		if (xhtml.name == "br") {
			return "\n";
		}

		if (xhtml.name == "img") {
			return xhtml.attr.get("alt") ?? "";
		}

		final s = new StringBuf();

		if (xhtml.name == "pre") {
			s.add("\n```\n");
		}

		if (xhtml.name == "b" || xhtml.name == "strong") {
			s.add("*");
		}

		if (xhtml.name == "i" || xhtml.name == "em") {
			s.add("_");
		}

		if (xhtml.name == "s" || xhtml.name == "del") {
			s.add("~");
		}

		if (xhtml.name == "tt") {
			s.add("`");
		}

		for (child in xhtml.children) {
			s.add(renderNode(child));
		}

		if (xhtml.name == "b" || xhtml.name == "strong") {
			s.add("*");
		}

		if (xhtml.name == "i" || xhtml.name == "em") {
			s.add("_");
		}

		if (xhtml.name == "s" || xhtml.name == "del") {
			s.add("~");
		}

		if (xhtml.name == "tt") {
			s.add("`");
		}

		if (xhtml.name == "blockquote" || xhtml.name == "p" || xhtml.name == "div" || xhtml.name == "pre") {
			s.add("\n");
		}

		if (xhtml.name == "pre") {
			s.add("```\n");
		}

		if (xhtml.name == "blockquote") {
			return ~/^/gm.replace(s.toString(), "> ");
		}

		return s.toString();
	}

	public static function renderNode(xhtml: Node) {
		return switch (xhtml) {
			case Element(c): render(c);
			case CData(c): c.content;
		};
	}

	public static function parseSpans(styled: UnicodeString) {
		final spans = [];
		var start = 0;
		var nextLink = null;
		final styledLength = styled.length;
		while (start < styledLength) {
			final char = styled.charAt(start);
			if (StringTools.isSpace(styled, start + 1)) {
				// The opening styling directive MUST NOT be followed by a whitespace character
				spans.push(CData(new TextNode(styled.substr(start, 2))));
				start += 2;
			} else if (start != 0 && !StringTools.isSpace(styled, start - 1)) {
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
		return spans;
	}

	public static function parseSpan(tagName: UnicodeString, marker: String, styled: String, start: Int) {
		var end = start + 1;
		while (end < styled.length && styled.charAt(end) != marker) {
			if (StringTools.isSpace(styled, end)) end++; // the closing styling directive MUST NOT be preceeded by a whitespace character
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
			if (end < styledLength && styled.charAt(end) == "\n") end++;
			return { block: new Stanza("div").addChildNodes(parseSpans(styled.substr(0, end))), rest: styled.substr(end) };
		}
	}

	public static function parseQuote(styled: UnicodeString) {
		final lines = [];
		var line = "";
		var end = 1; // Skip leading >
		var spaceAfter = 0;
		while (end < styled.length) {
			if (styled.charAt(end) != "\n" && StringTools.isSpace(styled, end)) end++;
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
		var line = null;
		var end = 0;
		final styledLength = styled.length;
		while (end < styledLength) {
			while (end < styledLength && styled.charAt(end) != "\n") {
				if (line != null) line += styled.charAt(end);
				end++;
			}
			if (end < styledLength && styled.charAt(end) == "\n") {
				end++;
			}
			if (line != null) lines.push(line+"\n");
			line = "";
			if (styled.substr(end, 4) == "```\n" || styled.substr(end) == "```") {
				end += 4;
				break;
			}
		}

		return { block: new Stanza("pre").text(lines.join("")), rest: styled.substr(end) };
	}
}
