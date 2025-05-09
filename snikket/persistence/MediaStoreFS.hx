package snikket.persistence;

#if cpp
import HaxeCBridge;
#end
import haxe.io.Bytes;
import haxe.io.BytesData;
import sys.FileSystem;
import sys.io.File;
import thenshim.Promise;

#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class MediaStoreFS implements MediaStore {
	private final blobpath: String;
	private var kv: Null<KeyValueStore> = null;

	public function new(path: String) {
		blobpath = path;
	}

	@:allow(snikket)
	private function setKV(kv: KeyValueStore) {
		this.kv = kv;
	}

	public function getMediaPath(uri: String, callback: (Null<String>)->Void) {
		final hash = Hash.fromUri(uri);
		if (hash.algorithm == "sha-256") {
			final path = blobpath + "/f" + hash.toHex();
			if (FileSystem.exists(path)) {
				callback(FileSystem.absolutePath(path));
			} else {
				callback(null);
			}
		} else {
			get(hash.serializeUri()).then(sha256uri -> {
				final sha256 = sha256uri == null ? null : Hash.fromUri(sha256uri);
				if (sha256 == null) {
					callback(null);
				} else {
					getMediaPath(sha256.toUri(), callback);
				}
			});
		}
	}

	@HaxeCBridge.noemit
	public function hasMedia(hashAlgorithm:String, hash:BytesData, callback: (Bool)->Void) {
		final hash = new Hash(hashAlgorithm, hash);
		getMediaPath(hash.toUri(), path -> callback(path != null));
	}

	@HaxeCBridge.noemit
	public function removeMedia(hashAlgorithm: String, hash: BytesData) {
		final hash = new Hash(hashAlgorithm, hash);
		getMediaPath(hash.toUri(), (path) -> {
			if (path != null) FileSystem.deleteFile(path);
		});
	}

	@HaxeCBridge.noemit
	public function storeMedia(mime: String, bd: BytesData, callback: ()->Void) {
		final bytes = Bytes.ofData(bd);
		final sha1 = Hash.sha1(bytes);
		final sha256 = Hash.sha256(bytes);
		File.saveBytes(blobpath + "/f" + sha256.toHex(), bytes);
		thenshim.PromiseTools.all([
			set(sha1.serializeUri(), sha256.serializeUri()),
			set(sha256.serializeUri() + "#contentType", mime)
		]).then((_) -> callback());
	}

	private function set(k: String, v: Null<String>) {
		if (kv == null) return Promise.resolve(null);

		return new Promise((resolve, reject) ->
			kv.set(k, v, () -> resolve(null))
		);
	}

	private function get(k: String): Promise<Null<String>> {
		if (kv == null) return Promise.resolve(null);

		return new Promise((resolve, reject) ->
			kv.get(k, resolve)
		);
	}
}
