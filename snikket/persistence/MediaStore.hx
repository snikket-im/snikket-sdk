package snikket.persistence;

import haxe.io.BytesData;

interface MediaStore {
	public function hasMedia(hashAlgorithm:String, hash:BytesData, callback: (has:Bool)->Void):Void;
	public function removeMedia(hashAlgorithm:String, hash:BytesData):Void;
	public function storeMedia(mime:String, bytes:BytesData, callback: ()->Void):Void;
	@:allow(snikket)
	private function setKV(kv: KeyValueStore):Void;
}
