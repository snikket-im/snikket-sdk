package snikket.persistence;

import thenshim.Promise;
import haxe.io.BytesData;

#if cpp
@:build(HaxeSwiftBridge.expose())
#end
interface MediaStore {
	public function hasMedia(hashAlgorithm:String, hash:BytesData): Promise<Bool>;
	public function removeMedia(hashAlgorithm:String, hash:BytesData):Void;
	public function storeMedia(mime:String, bytes:BytesData): Promise<Bool>;
	@:allow(snikket)
	private function setKV(kv: KeyValueStore):Void;
}
