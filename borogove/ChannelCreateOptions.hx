package borogove;

using StringTools;

#if cpp
import HaxeCBridge;
#end

@:expose
@:nullSafety(StrictThreaded)
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class ChannelCreateOptions {
	/**
		Service to create the channel on

		Will use the account default if not set
	**/
	public var service: Null<String> = null;

	/**
		Human-readable name for the channel.
	**/
	public var name: Null<String> = null;

	/**
		Localpart of the room ID
	**/
	public var localpart: Null<String> = null;

	/**
		Whether the room should be members only
	**/
	public var isPrivate: Bool = true;

	/**
		When true, leave the room locked after creation and let the caller
		submit the full owner configuration form before it is unlocked.
	**/
	public var deferConfig: Bool = false;

	public function new() {}

	/**
		Build the room JID for this channel on a MUC service.

		Uses `localpart` when supplied, otherwise derives one from `name`, and
		finally falls back to a generated UUID.

		@param service MUC service domain, for example `groups.example.com`
		@returns the room JID, for example `team@groups.example.com`
	**/
	public function jid(service: String) {
		final requested = localpart;
		var local = requested != null && requested.trim() != "" ? requested : slug(name);
		if (local == null || local == "") local = ID.unique();

		return new JID(local, service);
	}

	private static function slug(name: Null<String>): Null<String> {
		if (name == null) return null;

		var result = name.trim().toLowerCase();
		result = ~/[^a-z0-9]+/g.replace(result, "-");
		result = ~/^-+|-+$/g.replace(result, "");

		return result == "" ? null : result;
	}
}
