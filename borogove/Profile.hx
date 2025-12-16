package borogove;

import haxe.ds.ReadOnlyArray;
using Lambda;

import borogove.Stanza;

#if cpp
import HaxeCBridge;
#end

@:expose
@:nullSafety(Strict)
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Profile {
	@:allow(borogove.ProfileBuilder)
	private final vcard: Stanza;

	/**
		All items in the profile
	**/
	public final items: ReadOnlyArray<ProfileItem>;

	@:allow(borogove)
	private function new(vcard: Stanza, ?items: ReadOnlyArray<ProfileItem>) {
		this.vcard = vcard;
		this.items = items != null ? items : vcard.allTags().filter(el ->
			TYPES[el.name] != null // remove unknown or compound property
		).map(child -> new ProfileItem(child, child.name + "/" + ID.short()));
	}
}

@:expose
@:nullSafety(Strict)
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class ProfileItem {
	public final id: String;
	public final key: String;

	@:allow(borogove.ProfileBuilder)
	private final item: Stanza;

	@:allow(borogove.Profile)
	private function new(item: Stanza, id: String) {
		this.item = item;
		this.id = id;
		this.key = item.name;
	}

	public function parameters(): Array<ProfileItem> {
		final params = item.getChild("parameters")?.allTags() ?? [];
		return params.map(param -> new ProfileItem(param, id + "/" + ID.short()));
	}

	public function text(): Array<String> {
		return item.allTags("text").map(s -> s.getText());
	}

	public function uri(): Array<String> {
		return item.allTags("uri").map(s -> s.getText());
	}

	public function date(): Array<String> {
		return item.allTags("date").map(s -> s.getText());
	}

	public function time(): Array<String> {
		return item.allTags("time").map(s -> s.getText());
	}

	public function datetime(): Array<String> {
		return item.allTags("datetime").map(s -> s.getText());
	}

	@HaxeCBridge.noemit
	public function boolean(): Array<Bool> {
		return item.allTags("boolean").map(s -> s.getText() == "true");
	}

	@HaxeCBridge.noemit
	public function integer(): Array<Int> {
		return item.allTags("integer").map(s -> Std.parseInt(s.getText()) ?? 0);
	}

	public function languageTag(): Array<String> {
		return item.allTags("language-tag").map(s -> s.getText());
	}
}

final TYPES = [
	"source" => "uri",
	"kind" => "text",
	"fn" => "text",
	"nickname" => "text", // text list is allowed
	"photo" => "uri",
	"bday" => "date", // spec says date and/or time or text
	"anniversary" => "date", // same as bday
	"tel" => "uri", // spec says text is allowed for compatibility but SHOULD be URI
	"email" => "text",
	"impp" => "uri",
	"lang" => "language-tag",
	"tz" => "text", // spec allows utc-offset NOT RECOMMENDED and URI
	"geo" => "uri",
	"title" => "text",
	"role" => "text",
	"logo" => "uri",
	"org" => "text", // text list says spec. non-xml spec says structured
	"member" => "uri",
	"related" => "uri", // spec says text is allowed
	"categories" => "text", // text list is allowed
	"note" => "text",
	"prodid" => "text",
	"rev" => "timestamp",
	"sound" => "uri",
	"uid" => "uri", // MAY be text
	"url" => "uri",
	"version" => "text", // always 4 for now...
	"key" => "uri", // spec says may be text
	"fburl" => "uri",
	"caladruri" => "uri",
	"caluri" => "uri",
	"pronouns" => "text",
];

@:expose
@:nullSafety(Strict)
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class ProfileBuilder {
	private final vcard: Stanza;
	private var items: Array<ProfileItem> = [];

	public function new(profile: Profile) {
		vcard = profile.vcard.clone();
		final els = vcard.allTags().filter(el ->
			// Compound properties that don't follow the normal item rules
			!["n", "adr", "gender"].contains(el.name)
		);
		for (item in profile.items) {
			final el = els.shift();
			if (el == null || el.name != item.key) throw "els/items mismatch";
			items.push(new ProfileItem(el, item.id));
		}
	}

	/**
		Add a new field to this profile
	**/
	public function add(k: String, v: String) {
		final type = TYPES[k];
		if (type != null) {
			final el = new Stanza(k).textTag(type, v);
			vcard.addChild(el);
			items.push(new ProfileItem(el, k + "/" + ID.short()));
		} else {
			throw 'Unknown profile property ${k}';
		}
	}

	/**
		Set the value of an existing field on this profile
	**/
	public function set(id: String, v: String) {
		final parts = id.split("/");
		final k = parts[0];
		final prop = items.find(item -> item.id == id)?.item;
		if (prop == null) throw 'prop not found for ${id}';

		final type = TYPES[k];
		if (type != null) {
			prop.removeChildren();
			prop.textTag(type, v);
		} else {
			throw 'Unknown profile property ${k}';
		}
	}

	/**
		Move a profile item

		@param id the item to move
		@param moveTo the item currently in the position where it should move to
	**/
	public function move(id: String, moveTo: String) {
		final move = items.find(item -> item.id == id);
		if (move == null) throw 'item ${id} not found';

		final idx = items.findIndex(item -> item.id == moveTo);
		remove(id);
		items.insert(idx, move);
		vcard.insertChild(idx, move.item);
	}

	/**
		Remove a field from this profile
	**/
	public function remove(id: String) {
		final prop = items.find(item -> item.id == id);
		if (prop == null) return;

		items = items.filter(item -> item.id != id);
		vcard.removeChild(prop.item);
	}

	public function build() {
		return new Profile(vcard.clone(), items.array());
	}

	@:allow(borogove)
	private function buildStanza() {
		return vcard.clone();
	}
}
