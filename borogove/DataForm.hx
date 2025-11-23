package borogove;

import borogove.Stanza;

#if cpp
import HaxeCBridge;
#end

@:forward(toString)
abstract DataForm(Stanza) from Stanza to Stanza {
	public var title(get, never): Null<String>;
	public var type(get, never): Null<String>;
	public var fields(get, never): Array<Field>;
	public var tableHeader(get, never): Array<Field>;
	public var tableRows(get, never): Array<Array<Field>>;

	inline public function get_title() {
		return this.getChildText("title");
	}

	inline public function get_type() {
		return this.attr.get("type") ?? "form";
	}

	inline public function get_fields() {
		return this.allTags("field");
	}

	inline public function get_tableHeader() {
		return this.getChild("reported")?.allTags("field");
	}

	inline public function get_tableRows() {
		return this.allTags("item")?.map(row -> row.allTags("field"));
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
	public var desc(get, never): Null<String>;
	public var value(get, set): Array<String>;
	public var type(get, set): String;
	public var datatype(get, never): String;
	public var options(get, never): Array<Option>;
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

	inline public function get_desc() {
		return this.getChildText("desc");
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

	inline public function set_type(newType: String) {
		return this.attr.set("type", newType);
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

	public function get_options() {
		return this.allTags("option");
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

abstract Option(Stanza) from Stanza to Stanza {
	public var label(get, never): Null<String>;
	public var value(get, never): Null<String>;

	inline public function get_label() {
		return this.attr.get("label");
	}

	inline public function get_value() {
		return this.getChildText("value");
	}

	@:to
	inline public function toFormOption(): FormOption {
		return this == null ? null : FormOption.fromOption(this);
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
	public final desc: Null<String>;
	public final value: Array<String>;
	public final required: Bool;
	public final type: String;
	public final datatype: String;
	public final options: Array<FormOption>;
	public final open: Bool;
	public final rangeMin: Null<String>;
	public final rangeMax: Null<String>;
	public final regex: Null<String>;

	@:allow(borogove)
	private function new(field: Field) {
		name = field.name;
		label = field.label;
		desc = field.desc;
		value = field.value;
		required = field.required;
		type = field.type;
		datatype = field.datatype;
		options = field.options.map(o -> o.toFormOption());
		open = field.open;
		rangeMin = field.rangeMin;
		rangeMax = field.rangeMax;
		regex = field.regex;
	}
}

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class FormOption {
	public final label: String;
	public final value: String;

	@:allow(borogove)
	private function new(label: Null<String>, value: Null<String>) {
		this.label = label ?? value;
		this.value = value ?? "";
	}

	@:allow(borogove)
	private static function fromOption(option: Option) {
		return new FormOption(option.label, option.value);
	}
}
