package borogove.persistence;

import thenshim.Promise;

#if cpp
@:build(HaxeSwiftBridge.expose())
#end
interface KeyValueStore {
	public function get(k: String): Promise<Null<String>>;
	public function set(k: String, v: Null<String>): Promise<Bool>;
}
