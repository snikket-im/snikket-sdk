package borogove;

import borogove.DataForm;

#if cpp
import HaxeCBridge;
#end

@:expose
#if cpp
@:build(HaxeSwiftBridge.expose())
#end
interface FormSection {
	public function title(): Null<String>;
	public function items(): Array<FormItem>;
}

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class FormItem {
	public final text: Null<String>;
	public final field: Null<FormField>;
	public final section: Null<FormSection>;
	public final status: Null<String>;
	public final tableHeader: Null<Array<FormField>>;
	public final tableRows: Null<Array<Array<FormField>>>;

	@:allow(borogove)
	private function new(text: Null<String>, field: Null<FormField>, section: Null<FormSection>, tableHeader: Null<Array<FormField>> = null, tableRows: Null<Array<Array<FormField>>> = null, status: Null<String> = null) {
		this.text = text;
		this.field = field;
		this.section = section;
		this.tableHeader = tableHeader;
		this.tableRows = tableRows;
		this.status = status;
	}
}

#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class FormSubmitBuilder {
	private final data: Map<String, Array<String>> = [];

	public function new() { }

	public function add(k: String, v: String) {
		if (data.get(k) != null) {
			data.set(k, data.get(k).concat([v]));
		} else {
			data.set(k, [v]);
		}
	}

	@:allow(borogove)
	private function submit(form: Null<DataForm>) {
		final toSubmit = new Stanza("x", { xmlns: "jabber:x:data", type: "submit" });
		if (form != null) {
			for (f in form.fields) {
				if (data.get(f.name) == null && f.value.length > 0) {
					final tag = toSubmit.tag("field", { "var": f.name });
					for (v in f.value) {
						tag.textTag("value", v);
					}
					tag.up();
				} else if (f.required && (data.get(f.name) == null || data[f.name].length < 1)) {
					trace("No value provided for required field", f.name);
					return null;
				}
			}
		}
		for (k => vs in data) {
			final tag = toSubmit.tag("field", { "var": k });
			for (v in vs) {
				tag.textTag("value", v);
			}
			tag.up();
		}

		return toSubmit;
	}
}

typedef StringOrArray = haxe.extern.EitherType<String, Array<String>>;

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Form implements FormSection {
	private final form: Null<DataForm>;
	private final oob: Null<OOB>;

	@:allow(borogove)
	private function new(form: Null<DataForm>, oob: Null<OOB>) {
		if (form == null && oob == null) throw "Need a form or OOB";
		this.form = form;
		this.oob = oob;
	}

	/**
		Is this form entirely results / read-only?
	**/
	public function isResult() {
		if (form == null) return true;

		return form.type == "result";
	}

	/**
		Title of this form
	**/
	public function title() {
		return form != null ? form.title : oob.desc;
	}

	/**
		URL to use instead of this form
	**/
	public function url() {
		return oob?.url;
	}

	/**
		Items to render inside this form
	**/
	public function items(): Array<FormItem> {
		if (form == null) return [];

		final s: Stanza = form;
		final hasLayout = s.getChild("page", "http://jabber.org/protocol/xdata-layout") != null;
		final items = [];
		for (child in s.allTags()) {
			if (child.name == "instructions" && (child.attr.get("xmlns") == null || child.attr.get("xmlns") == "jabber:x:data")) {
				items.push(new FormItem(child.getText(), null, null, null, null, child.attr.get("type")));
			}
			if (!hasLayout && child.name == "field" && (child.attr.get("xmlns") == null || child.attr.get("xmlns") == "jabber:x:data")) {
				final fld: Null<Field> = child;
				if (fld.type == "fixed" && fld.label == null) {
					for (v in fld.value) {
						items.push(new FormItem(v, null, null));
					}
				} else if (fld.type != "hidden") {
					items.push(new FormItem(null, fld, null));
				}
			}
			if (!hasLayout && child.name == "reported" && (child.attr.get("xmlns") == null || child.attr.get("xmlns") == "jabber:x:data")) {
				items.push(new FormItem(
					null, null, null,
					form.tableHeader?.map(f -> f.toFormField()),
					form.tableRows?.map(row -> row.map(f -> f.toFormField())) ?? []
				));
			}
			if (child.name == "page" && child.attr.get("xmlns") == "http://jabber.org/protocol/xdata-layout") {
				items.push(new FormItem(null, null, new FormLayoutSection(form, child)));
			}
		}

		return items;
	}

	#if js
	@:allow(borogove)
	private function submit(
		data: haxe.extern.EitherType<
			haxe.extern.EitherType<
				haxe.DynamicAccess<StringOrArray>,
				Map<String, StringOrArray>
			>,
			js.html.FormData
		>
	) {
		final builder = new FormSubmitBuilder();

		if (Std.isOfType(data, js.lib.Map)) {
			for (k => v in ((cast data) : Map<String, StringOrArray>)) {
				if (Std.isOfType(v, String)) {
					builder.add(k, v);
				} else {
					for (oneV in ((cast v) : Array<String>)) {
						builder.add(k, oneV);
					}
				}
			}
		#if !nodejs
		} else if (Std.isOfType(data, js.html.FormData)) {
			for (entry in new js.lib.HaxeIterator(((cast data) : js.html.FormData).entries())) {
				if (form.field(entry[0])?.type == "boolean") {
					// FormData may have booleans formatted like an HTML form
					builder.add(entry[0], entry[1] == "on" ? "true" : "false");
				} else {
					builder.add(entry[0], entry[1]);
				}
			}
		#end
		} else if (data != null) {
			for (k => v in ((cast data) : haxe.DynamicAccess<StringOrArray>)) {
				if (Std.isOfType(v, String)) {
					builder.add(k, v);
				} else {
					for (oneV in ((cast v) : Array<String>)) {
						builder.add(k, oneV);
					}
				}
			}
		}

		return builder.submit(form);
	}
	#else
	@:allow(borogove)
	private function submit(data: FormSubmitBuilder) {
		return data.submit(form);
	}
	#end
}

class FormLayoutSection implements FormSection {
	private final form: DataForm;
	private final section: Stanza;

	@:allow(borogove)
	private function new(form: DataForm, section: Stanza) {
		this.form = form;
		this.section = section;
	}

	public function title() {
		return section.attr.get("label");
	}

	public function items() {
		final items = [];
		for (child in section.allTags()) {
			if (child.name == "text" && (child.attr.get("xmlns") == null || child.attr.get("xmlns") == "http://jabber.org/protocol/xdata-layout")) {
				items.push(new FormItem(child.getText(), null, null));
			}
			if (child.name == "fieldref" && (child.attr.get("xmlns") == null || child.attr.get("xmlns") == "http://jabber.org/protocol/xdata-layout")) {
				items.push(new FormItem(null, form.field(child.attr.get("var")), null));
			}
			if (child.name == "reportedref" && (child.attr.get("xmlns") == null || child.attr.get("xmlns") == "http://jabber.org/protocol/xdata-layout")) {
				items.push(new FormItem(
					null, null, null,
					form.tableHeader?.map(f -> f.toFormField()),
					form.tableRows?.map(row -> row.map(f -> f.toFormField())) ?? []
				));
			}
			if (child.name == "section" && (child.attr.get("xmlns") == null || child.attr.get("xmlns") == "http://jabber.org/protocol/xdata-layout")) {
				items.push(new FormItem(null, null, new FormLayoutSection(form, child)));
			}
		}

		return items;
	}
}
