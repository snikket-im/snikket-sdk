package borogove;

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
	private final vcard: Stanza;

	@:allow(borogove)
	private function new(vcard: Stanza) {
		this.vcard = vcard;
	}

	/**
		Get a property from the profile

		@param key what property to get
		@returns the property value
	**/
	public function get(key: String): Array<ProfileItem> {
		return vcard.allTags(key).map(child -> new ProfileItem(child));
	}

	/**
		List the regular properties which can be represented by a ProfileItem
	**/
	public function properties(): Array<String> {
		final names = vcard.allTags().map(el -> el.name);
		final result = [];
		final seen: Map<String, Bool> = [];

		for (name in names) {
			// Compound properties that don't follow the normal rules
			if (seen[name] != true && !["n", "adr", "gender"].contains(name)) {
				seen[name] = true;
				result.push(name);
			}
		}

		return result;
	}
}

@:expose
@:nullSafety(Strict)
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class ProfileItem {
	private final item: Stanza;

	@:allow(borogove.Profile)
	private function new(item: Stanza) {
		this.item = item;
	}

	public function key() {
		return item.name;
	}

	public function parameters(): Array<ProfileItem> {
		final params = item.getChild("parameters")?.allTags() ?? [];
		return params.map(param -> new ProfileItem(param));
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
