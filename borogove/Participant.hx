package borogove;

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
	public final isSelf: Bool;

	@:allow(borogove)
	private function new(displayName: String, photoUri: Null<String>, placeholderUri: String, isSelf: Bool) {
		this.displayName = displayName;
		this.photoUri = photoUri;
		this.placeholderUri = placeholderUri;
		this.isSelf = isSelf;
	}
}
