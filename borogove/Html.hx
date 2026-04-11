package borogove;

import haxe.DynamicAccess;
import haxe.ds.ReadOnlyArray;
using StringTools;
using Lambda;

import borogove.Stanza;

#if cpp
import HaxeCBridge;
#end

@:expose
@:nullSafety(StrictThreaded)
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
/**
	Rich text

	WARNING: this is possibly untrusted HTML. You must render or sanitize appropriately!
**/
class Html {
	private static final HTML_EMPTY = [
		"area",
		"base",
		"br",
		"col",
		"embed",
		"hr",
		"img",
		"input",
		"link",
		"meta",
		"param",
		"source",
		"track",
		"wbr"
	];

	@:allow(borogove)
	private final xml: ReadOnlyArray<Node>;
	private final sender: Null<Participant>;

	@:allow(borogove)
	private function new(xml: Array<Node>, sender: Null<Participant>) {
		this.xml = xml;
		this.sender = sender;
	}

	#if js
	/**
		HTML builder, make an element
	**/
	public static function element(tag: String, attrs: DynamicAccess<String>, children: Array<Html>) {
		final s = new Stanza(tag, attrs);
		for (c in children) {
			for (n in c.xml) {
				s.addDirectChild(n);
			}
		}

		return new Html([Element(s)], null);
	}
	#else
	/**
		HTML builder, make an element
	**/
	public static function element(tag: String, attr: Array<String>, attrValues: Array<String>, children: Array<Html>) {
		final attrs: DynamicAccess<String> = {};
		for (i => a in attr) {
			attrs[a] = attrValues[i];
		}

		final s = new Stanza(tag, attrs);
		for (c in children) {
			for (n in c.xml) {
				s.addDirectChild(n);
			}
		}

		return new Html([Element(s)], null);
	}
	#end

	/**
		HTML builder, make some text
	**/
	public static function text(text: String) {
		return new Html([CData(new TextNode(text))], null);
	}

	/**
		Build HTML payload from source
	**/
	public static function fromString(html: String): Html {
		final nodes = [];
		for (node in htmlparser.HtmlParser.run(html, true)) {
			final el = Util.downcast(node, htmlparser.HtmlNodeElement);
			if (el != null && (el.name == "html" || el.name == "body")) {
				for (inner in el.nodes) {
					nodes.push(htmlToNode(inner));
				}
			} else {
				nodes.push(htmlToNode(node));
			}
		}
		return new Html(nodes, null);
	}

	private static function htmlToNode(node: htmlparser.HtmlNode) {
		final txt = Util.downcast(node, htmlparser.HtmlNodeText);
		if (txt != null) {
			return CData(new TextNode(txt.toText()));
		}
		final el = Util.downcast(node, htmlparser.HtmlNodeElement);
		if (el != null) {
			final s = new Stanza(el.name, {});
			for (attr in el.attributes) {
				s.attr.set(attr.name, attr.value);
			}
			for (child in el.nodes) {
				s.addDirectChild(htmlToNode(child));
			}
			return Element(s);
		}
		throw "node was neither text nor element?";
	}

	@:allow(borogove)
	private function isPlainText() {
		// Don't use our own reduce because we want to check the raw nodes
		return !xml.map(item -> switch (item) {
			case Element(el):
				el.reduce(
					(st, kids) -> {
						final attrs = st.attr.keys();

						if (["div", "span", "p", "br"].contains(st.name)) {
							return attrs.length < 1 && !kids.exists(plain -> !plain);
						}

						return false;
					},
					txt -> true
				);
			case CData(txt): true;
		}).exists(plain -> !plain);
	}

	/**
		Walk the HTML tree to produce a new value
	**/
	public function reduce<T>(f: (String, Null<Array<String>>, Null<Array<String>>, Null<Array<T>>)->T):Array<T> {
		var isAction = false;

		function mkTxt(txt: String) {
			final senderP = sender;
			return if (!isAction && txt.startsWith("/me ") && senderP != null) {
				isAction = true;
				f(senderP.displayName + txt.substr(3), null, null, null);
			} else {
				f(txt, null, null, null);
			};
		}

		final fragment = xml.map(item -> switch (item) {
			case Element(el):
				el.reduce(
					(st, kids) -> {
						// We don't deeply sanitize but we can remove some obvious dumb stuff
						if (st.name == "style" || st.name == "script") return mkTxt("");

						final keys = st.attr.keys().filter(k -> !k.startsWith("on"));
						return f(
							st.name,
							keys,
							keys.map(k -> {
								final v = st.attr.get(k) ?? "";
								if (st.name == "img" && k == "src" && v != "") {
									final hash = Hash.fromUri(v);
									hash == null ? v : hash.toUri();
								} else {
									v;
								}
							}),
							kids
						);
					},
					txt -> mkTxt(txt)
				);
			case CData(txt):
				mkTxt(txt.content);
		});
		return isAction ? [f("div", ["class"], ["action"], fragment)] : fragment;
	}

	/**
		Get HTML source as a string
	**/
	public function toString(): String {
		return reduce((tag, attr, attrValue, kids) -> {
			if (attr == null && kids == null) {
				return StringTools.htmlEscape(tag);
			} else if (attr != null && attrValue != null) {
				final el = Xml.createElement(tag);
				for (i => attr_k in attr) {
					el.set(attr_k, attrValue[i]);
				}

				final start = el.toString();
				final buffer = new StringBuf();
				buffer.addSub(start, 0, start.length-2);

				if (HTML_EMPTY.contains(tag)) {
					buffer.add(" />");
					return buffer.toString();
				}

				buffer.add(">");
				if (kids != null) {
					for (kid in kids) {
						buffer.add(kid);
					}
				}

				buffer.add("</");
				buffer.add(tag);
				buffer.add(">");
				return buffer.toString();
			}

			throw "Invalid arguments";
		}).join("");
	}

	/**
		Get plain text suitable for showing to a user
	**/
	public function toPlainText(): String {
		// Could use reduce, but we already have XEP0393.render around
		final body = new Stanza("body");
		body.addChildNodes(xml);
		return ~/\n$/.replace(XEP0393.render(body), "");
	}

	#if js
	/**
		Get HTML as a DocumentFragment
	**/
	public function asDOM(): js.html.DocumentFragment {
		final nodes = reduce((tag, attr, attrValue, kids) -> {
			if (attr == null && kids == null) {
				return (js.Browser.document.createTextNode(tag) : js.html.Node);
			} else if (attr != null && attrValue != null) {
				final el = js.Browser.document.createElement(tag);
				for (i => attr_k in attr) {
					el.setAttribute(attr_k, attrValue[i]);
				}
				if (kids != null) el.append(...kids);
				return el;
			}

			throw "Invalid arguments";
		});

		final frag = new js.html.DocumentFragment();
		frag.append(...nodes);
		return frag;
	}
#end
}
