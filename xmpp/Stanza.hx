package xmpp;

import haxe.DynamicAccess;
import haxe.Exception;
import haxe.ds.StringMap;

enum Node {
	Element(stanza:Stanza);
	CData(textNode:TextNode);
}

typedef NodeList = Array<Node>;

private interface NodeInterface {
	public function serialize():String;
	public function clone():NodeInterface;
}

class TextNode implements NodeInterface {
	private var content(default, null):String = "";

	public function new (content:String) {
		this.content = content;
	}

	public function serialize():String {
		return content;
	}

	public function clone():TextNode {
		return new TextNode(this.content);
	}
}

class Stanza implements NodeInterface {
	public var name(default, null):String = null;
	public var attr(default, null):DynamicAccess<String> = null;
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
		var buffer = [serialized.substring(0, serialized.length-2)+">"];
		for (child in children) {
			buffer.push(switch (child) {
				case Element(c): c.serialize();
				case CData(c): c.serialize();
			});
		}
		buffer.push("</"+this.name+">");
		return buffer.join("");
	}

	public function toString():String {
		return this.serialize();
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
		this.last_added.addDirectChild(Element(new Stanza(tagName, attr).text(textContent)));
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
				return (name == null || child.name == name
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
					case CData(c): c.serialize();
					case _: null;
				};
			});
	}

	public function getFirstChild():Stanza {
		return allTags()[0];
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

	public function find(path:String):Node {
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

	public function findText(path:String):String {
		var result = find(path);
		if(result == null) {
			return null;
		}
		return switch(result) {
			case CData(textNode): textNode.serialize();
			case _: null;
		};
	}
}
