package borogove;

#if cpp
import HaxeCBridge;
import cpp.NativeGc;
#end

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Config {
	/**
		Produce /.well-known/ni/ paths instead of ni:/// URIs
		for referencing media by hash.

		This can be useful eg for intercepting with a Service Worker.
	**/
	public static var relativeHashUri = false;

	@:allow(borogove)
	private static var constrainedMemoryMode = false;

	#if cpp
	/**
		Trades off some performance for lower / more consistent memory usage
	**/
	public static function enableConstrainedMemoryMode() {
		NativeGc.setMinimumFreeSpace(500000);
		NativeGc.setTargetFreeSpacePercentage(5);
		constrainedMemoryMode = true;
	}
	#end
}
