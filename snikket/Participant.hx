package snikket;

#if cpp
import HaxeCBridge;
#end

@:expose
@:nullSafety(Strict)
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Participant {
	public final displayName: String;
	public final photoUri: Null<String>;
	public final placeholderUri: String;

	@:allow(snikket)
	private function new(displayName: String, photoUri: Null<String>, placeholderUri: String) {
		this.displayName = displayName;
		this.photoUri = photoUri;
		this.placeholderUri = placeholderUri;
	}
}
