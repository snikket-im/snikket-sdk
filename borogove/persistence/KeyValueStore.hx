package borogove.persistence;

import thenshim.Promise;

#if cpp
import HaxeCBridge;
#end

#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
interface KeyValueStore {
	public function get(k: String): Promise<Null<String>>;
	public function set(k: String, v: Null<String>): Promise<Bool>;
}
