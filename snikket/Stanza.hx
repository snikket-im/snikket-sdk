package snikket;

import haxe.DynamicAccess;
import haxe.Exception;
import haxe.ds.StringMap;
import Xml;

enum Node {
	Element(stanza:Stanza);
	CData(textNode:TextNode);
}

typedef NodeList = Array<Node>;

private interface NodeInterface {
	public function serialize():String;
	public function clone():NodeInterface;
	public function traverse(f: (Stanza)->Bool):NodeInterface;
}

class TextNodeClass implements NodeInterface {
	public var content(get, never):String;
	private final node: TextNode;

	public function new(node: TextNode) {
		this.node = node;
	}

	private function get_content(): String {
		return node.content;
	}

	public function serialize():String {
		return node.serialize();
	}

	public function clone():TextNodeClass {
		return this;
	}

	public function traverse(f: (Stanza)->Bool) {
		return this;
	}
}

abstract TextNode(String) {
	public var content(get, never):String;

	inline public function new(content:String) {
		this = content;
	}

	inline private function get_content(): String {
		return this;
	}

	inline public function serialize():String {
		return Util.xmlEscape(this);
	}

	inline public function clone():TextNode {
		return new TextNode(this);
	}

	inline public function toClass() {
		return new TextNodeClass(new TextNode(this));
	}
}

class StanzaError {
	public var type:String;
	public var condition:String;
	public var text:Null<String>;

	public function new(type_:String, condition_:String, ?text_:String) {
		type = type_;
		condition = condition_;
		text = text_;
	}
}

@:expose
class Stanza implements NodeInterface {
	public var name(default, null):String = null;
	public var attr(default, null):DynamicAccess<String> = {};
	public var children(default, null):Array<Node> = [];
	private var last_added(null, null):Stanza;
	private var last_added_stack(null, null):Array<Stanza> = [];

	public function new(name:String, ?attr:DynamicAccess<String>) {
		this.name = name;
		if(attr != null) {
			this.attr = attr;
		}
		this.last_added = this;
	};

	public function serialize():String {
		var el = Xml.createElement(name);
		for (attr_k in this.attr.keys()) {
			el.set(attr_k, this.attr.get(attr_k));
		}

		if (this.children.length == 0) {
			return el.toString();
		}
		var serialized = el.toString();
		var buffer = new StringBuf();
		buffer.addSub(serialized, 0, serialized.length-2);
		buffer.add(">");
		for (child in children) {
			buffer.add(switch (child) {
				case Element(c): c.serialize();
				case CData(c): c.serialize();
			});
		}
		buffer.add("</");
		buffer.add(name);
		buffer.add(">");
		return buffer.toString();
	}

	public function toString():String {
		return this.serialize();
	}

	public static function parse(s:String):Stanza {
		#if cpp
		return snikket.streams.XmppStropheStream.parseStanza(s);
		#else
		return fromXml(Xml.parse(s));
		#end
	}

	@:allow(snikket)
	@:allow(test)
	private static function fromXml(el:Xml):Stanza {
		if(el.nodeType == XmlType.Document) {
			return fromXml(el.firstElement());
		}

		var attrs: DynamicAccess<String> = {};
		for (a in el.attributes()) {
			attrs.set(a, el.get(a));
		}
		var stanza = new Stanza(el.nodeName, attrs);
		for (child in el) {
			if(child.nodeType == XmlType.Element) {
				stanza.addChild(fromXml(child));
			} else if (child.nodeType == XmlType.ProcessingInstruction || child.nodeType == XmlType.DocType || child.nodeType == XmlType.Comment) {
				// Ignore non-operative XML items
			} else {
				stanza.text(child.nodeValue);
			}
		}
		return stanza;
	}

	public function tag(name:String, ?attr:DynamicAccess<String>) {
		var child = new Stanza(name, attr);
		this.last_added.addDirectChild(Element(child));
		this.last_added_stack.push(this.last_added);
		this.last_added = child;
		return this;
	}

	public function text(content:String) {
		this.last_added.addDirectChild(CData(new TextNode(content)));
		return this;
	}

	public function textTag(tagName:String, textContent:String, ?attr:DynamicAccess<String>) {
		this.last_added.addDirectChild(Element(new Stanza(tagName, attr ?? {}).text(textContent)));
		return this;
	}

	public function up() {
		if(this.last_added != this) {
			this.last_added = this.last_added_stack.pop();
		}
		return this;
	}

	public function reset():Stanza {
		this.last_added = this;
		return this;
	}

	@:allow(snikket)
	private function addChildren(children:Iterable<Stanza>) {
		for (child in children) {
			addChild(child);
		}
		return this;
	}

	@:allow(snikket)
	private function addChildNodes(children:Iterable<Node>) {
		for (child in children) {
			addDirectChild(child);
		}
		return this;
	}

	public function addChild(stanza:Stanza) {
		this.last_added.children.push(Element(stanza));
		return this;
	}

	public function addDirectChild(child:Node) {
		this.children.push(child);
		return this;
	}

	public function clone():Stanza {
		var clone = new Stanza(this.name, this.attr);
		for (child in children) {
			clone.addDirectChild(switch(child) {
				case Element(c): Element(c.clone());
				case CData(c): CData(c.clone());
			});
		}
		return clone;
	}

	public function allTags(?name:String, ?xmlns:String):Array<Stanza> {
		var tags = this.children
			.filter((child) -> child.match(Element(_)))
			.map(function (child:Node) {
				return switch(child) {
					case Element(c): c;
					case _: null;
				};
			});
		if (name != null || xmlns != null) {
			var ourXmlns = this.attr.get("xmlns");
			tags = tags.filter(function (child:Stanza):Bool {
				var childXmlns = child.attr.get("xmlns");
				return ((name == null || child.name == name)
				  && ((xmlns == null && (ourXmlns == childXmlns || childXmlns == null))
				     || childXmlns == xmlns));
			});
		}
		return tags;
	}

	public function allText():Array<String> {
		return this.children
			.filter((child) -> child.match(CData(_)))
			.map(function (child:Node) {
				return switch(child) {
					case CData(c): c.content;
					case _: null;
				};
			});
	}

	public function getFirstChild():Stanza {
		return allTags()[0];
	}

	public function getChildren():Array<NodeInterface> {
		return children.map(child -> switch(child) {
			case Element(el): el;
			case CData(text): text.toClass();
		});
	}

	public function getChild(?name:Null<String>, ?xmlns:Null<String>):Null<Stanza> {
		var ourXmlns = this.attr.get("xmlns");
		/*
		for (child in allTags()) {
			if (name == null || child.name == name
			    && ((xmlns == null && ourXmlns == child.attr.get("xmlns"))
			        || child.attr.get("xmlns") == xmlns)) {
				return child;
			}
		}*/
		var tags = allTags(name, xmlns);
		if(tags.length == 0) {
			return null;
		}
		return tags[0];
	}

	public function getChildText(?name:Null<String>, ?xmlns:Null<String>):String {
		var child = getChild(name, xmlns);
		if(child == null) {
			return null;
		}
		return child.getText();
	}

	public function getText():String {
		return allText().join("");
	}

	public function find(path:String): Null<Node> {
		var pos = 0;
		var len = path.length;
		var cursor = this;

		do {
			var xmlns = null, name = null, text = null;
			var char = path.charAt(pos);
			if (char == "@") {
				return CData(new TextNode(cursor.attr.get(path.substr(pos+1))));
			} else if (char == "{") {
				xmlns = path.substring(pos+1, path.indexOf("}", pos+1));
				pos += xmlns.length + 2;
			}
			var reName = new EReg("([^@/#]*)([/#]?)", "");
			if(!reName.matchSub(path, pos)) {
				throw new Exception("Invalid path to Stanza.find(): "+path);
			}
			var name = reName.matched(1), text = reName.matched(2);
			pos = reName.matchedPos().pos + reName.matchedPos().len;
			if(name == "") {
				name = null;
			};
			if(pos == len) {
				if(text == "#") {
					var text = cursor.getChildText(name, xmlns);
					if(text == null) {
						return null;
					}
					return CData(new TextNode(text));
				}
				return Element(cursor.getChild(name, xmlns));
			}
			cursor = cursor.getChild(name, xmlns);
		} while (cursor != null);
		return null;
	}

	public function findChild(path:String):Stanza {
		var result = find(path);
		if(result == null) {
			return null;
		}
		return switch(result) {
			case Element(stanza): stanza;
			case _: null;
		};
	}

	public function findText(path:String):Null<String> {
		var result = find(path);
		if(result == null) {
			return null;
		}
		return switch(result) {
			case CData(textNode): textNode.content;
			case _: null;
		};
	}

	public function traverse(f: (Stanza)->Bool) {
		if (!f(this)) {
			for (child in allTags()) {
				child.traverse(f);
			}
		}
		return this;
	}

	public function getError():Null<StanzaError> {
		final errorTag = this.getChild("error");
		if(errorTag == null) {
			return null;
		}
		return new StanzaError(
			errorTag.attr.get("type"),
			errorTag.getChild(null, "urn:ietf:params:xml:ns:xmpp-stanzas")?.name,
			errorTag.getChildText("text", "urn:ietf:params:xml:ns:xmpp-stanzas")
		);
	}

	public function removeChildren(?name: String, ?xmlns_:String):Void {
		final xmlns = xmlns_??attr.get("xmlns");
		children = children.filter((child:Node) -> {
			switch(child) {
				case Element(c):
					return !( (name == null || c.name == name) && c.attr.get("xmlns")??xmlns == xmlns);
				default:
					return true;
			}
		});
	}

	static public function parseXmlBool(x:String) {
		return x == "true" || x == "1";
	}
}

enum IqRequestType {
	Get;
	Set;
}
