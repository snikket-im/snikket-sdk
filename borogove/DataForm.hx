package borogove;

import borogove.Stanza;

#if cpp
import HaxeCBridge;
#end

@:forward(toString)
abstract DataForm(Stanza) from Stanza to Stanza {
	public var title(get, never): Null<String>;
	public var fields(get, never): Array<Field>;

	inline public function get_title() {
		return this.getChildText("title");
	}

	inline public function get_fields() {
		return this.allTags("field");
	}

	public function field(name: String): Null<Field> {
		final matches = fields.filter(f -> f.name == name);
		if (matches.length > 1) {
			trace('Multiple fields matching ${name}');
		}
		return matches[0];
	}
}

abstract Field(Stanza) from Stanza to Stanza {
	public var name(get, never): String;
	public var label(get, never): Null<String>;
	public var value(get, set): Array<String>;
	public var type(get, never): String;
	public var datatype(get, never): String;
	public var open(get, never): Bool;
	public var rangeMin(get, never): Null<String>;
	public var rangeMax(get, never): Null<String>;
	public var regex(get, never): Null<String>;
	public var required(get, never): Bool;

	inline public function get_name() {
		return this.attr.get("var") ?? "";
	}

	inline public function get_label() {
		return this.attr.get("label");
	}

	public function get_value() {
		final isbool = (this : Field).datatype == "xs:boolean";
		return this.allTags("value").map(v -> {
			final txt = v.getText();
			if (isbool) {
				Stanza.parseXmlBool(txt) ? "true" : "false";
			} else {
				return txt;
			}
		});
	}

	public function set_value(val: Array<String>) {
		this.removeChildren("value");
		for (v in val) {
			this.textTag("value", v);
		}
		return val;
	}

	inline public function get_type() {
		final attr = this.attr.get("type");

		// We will treat jid as a datatype not a field type
		if (attr == "jid-single") return "text-single";
		if (attr == "jid-multi") return "text-multi";
		return attr;
	}

	public function get_datatype() {
		final validate = this.getChild("validate", "http://jabber.org/protocol/xdata-validate");
		if (validate != null && validate.attr.get("datatype") != null) {
			return validate.attr.get("datatype");
		}
		if (["jid-single", "jid-multi"].contains(this.attr.get("type"))) {
			return "jid";
		}
		if (this.attr.get("type") == "boolean") return "xs:boolean";
		return "xs:string";
	}

	inline public function get_open() {
		final validate = this.getChild("validate", "http://jabber.org/protocol/xdata-validate");
		return validate?.getChild("open") != null;
	}

	inline public function get_rangeMin() {
		return range()?.attr?.get("min");
	}

	inline public function get_rangeMax() {
		return range()?.attr?.get("max");
	}

	inline private function range() {
		final validate = this.getChild("validate", "http://jabber.org/protocol/xdata-validate");
		return validate?.getChild("range");
	}

	inline public function get_regex() {
		final validate = this.getChild("validate", "http://jabber.org/protocol/xdata-validate");
		return validate?.getChildText("regex");
	}

	inline public function get_required() {
		return this.getChild("required") != null;
	}

	@:to
	inline public function toFormField(): FormField {
		return this == null ? null : new FormField(this);
	}
}

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class FormField {
	public final name: String;
	public final label: Null<String>;
	public final value: Array<String>;
	public final required: Bool;
	public final type: String;
	public final datatype: String;
	public final open: Bool;
	public final rangeMin: Null<String>;
	public final rangeMax: Null<String>;
	public final regex: Null<String>;

	@:allow(borogove)
	private function new(field: Field) {
		name = field.name;
		label = field.label;
		value = field.value;
		required = field.required;
		type = field.type;
		datatype = field.datatype;
		open = field.open;
		rangeMin = field.rangeMin;
		rangeMax = field.rangeMax;
		regex = field.regex;
	}
}
