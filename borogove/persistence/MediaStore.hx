package borogove.persistence;

import thenshim.Promise;
import haxe.io.BytesData;

#if cpp
import HaxeCBridge;
#end

#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
interface MediaStore {
	public function hasMedia(hashAlgorithm:String, hash:BytesData): Promise<Bool>;
	public function removeMedia(hashAlgorithm:String, hash:BytesData): Promise<Bool>;
	public function storeMedia(mime:String, source:Source): Promise<String>;
	@:allow(borogove)
	private function setKV(kv: KeyValueStore):Void;
}
