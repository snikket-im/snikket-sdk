package borogove;

#if cpp
import HaxeCBridge;
#end

@:expose
@:nullSafety(StrictThreaded)
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
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

	public static function asString(tag: String, attr: Null<Array<String>>, attrValue: Null<Array<String>>, kids: Null<Array<String>>): String {
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
	}

	#if js
	public static function asDOM(tag: String, attr: Null<Array<String>>, attrValue: Null<Array<String>>, kids: Null<Array<js.html.Node>>): js.html.Node {
		if (attr == null && kids == null) {
			return js.Browser.document.createTextNode(tag);
		} else if (attr != null && attrValue != null) {
			final el = js.Browser.document.createElement(tag);
			for (i => attr_k in attr) {
				el.setAttribute(attr_k, attrValue[i]);
			}
			if (kids != null) el.append(...kids);
			return el;
		}

		throw "Invalid arguments";
	}
#end
}
