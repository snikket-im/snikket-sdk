package borogove;

import borogove.Color;

@:expose
@:nullSafety(Strict)
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Role {
	// A role is the unification of XMPP affiliations and hats
	// importantly, it is *not* and XMPP MUC role

	/**
		Unique id for the role
	**/
	public final id: String;

	/**
		Human readable name for the role
	**/
	public final title: String;

	@:allow(borogove)
	private function new(id: String, title: String) {
		this.id = id;
		this.title = title;
	}

	@:allow(borogove)
	private static function forAffiliation(aff: String) {
		final title = switch (aff) {
			case "outcast": "Banned";
			case "member": "Member";
			case "admin": "Admin";
			case "owner": "Owner";
			default: return null;
		}
		return new Role(aff, title);
	}

	/**
		Suggested color to use when displaying this Role
	**/
	public function color() {
		return Color.forString(id);
	}
}
