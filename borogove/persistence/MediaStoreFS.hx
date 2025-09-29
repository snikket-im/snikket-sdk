package borogove.persistence;

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
@HaxeCBridge.name("borogove_persistence_media_store_fs")
#end
class MediaStoreFS implements MediaStore {
	private final blobpath: String;
	private var kv: Null<KeyValueStore> = null;

	/**
		Store media on the filesystem

		@param path where on filesystem to store media
	**/
	public function new(path: String) {
		blobpath = path;
	}

	@:allow(borogove)
	private function setKV(kv: KeyValueStore) {
		this.kv = kv;
	}

	/**
		Get absolute path on filesystem to a particular piece of media

		@param uri The URI to the media (ni:// or similar)
		@returns Promise resolving to the path or null
	**/
	public function getMediaPath(uri: String): Promise<Null<String>> {
		final hash = Hash.fromUri(uri);
		if (hash.algorithm == "sha-256") {
			final path = blobpath + "/f" + hash.toHex();
			if (FileSystem.exists(path)) {
				return Promise.resolve(FileSystem.absolutePath(path));
			} else {
				return Promise.resolve(null);
			}
		} else {
			return get(hash.serializeUri()).then(sha256uri -> {
				final sha256 = sha256uri == null ? null : Hash.fromUri(sha256uri);
				if (sha256 == null) {
					return Promise.resolve(null);
				} else {
					return getMediaPath(sha256.toUri());
				}
			});
		}
	}

	@HaxeCBridge.noemit
	public function hasMedia(hashAlgorithm:String, hash:BytesData): Promise<Bool> {
		final hash = new Hash(hashAlgorithm, hash);
		return getMediaPath(hash.toUri()).then(path -> path != null);
	}

	@HaxeCBridge.noemit
	public function removeMedia(hashAlgorithm: String, hash: BytesData) {
		final hash = new Hash(hashAlgorithm, hash);
		getMediaPath(hash.toUri()).then((path) -> {
			if (path != null) FileSystem.deleteFile(path);
		});
	}

	@HaxeCBridge.noemit
	public function storeMedia(mime: String, bd: BytesData): Promise<Bool> {
		final bytes = Bytes.ofData(bd);
		final sha1 = Hash.sha1(bytes);
		final sha256 = Hash.sha256(bytes);
		File.saveBytes(blobpath + "/f" + sha256.toHex(), bytes);
		return thenshim.PromiseTools.all([
			set(sha1.serializeUri(), sha256.serializeUri()),
			set(sha256.serializeUri() + "#contentType", mime)
		]).then(_ -> true);
	}

	private function set(k: String, v: Null<String>) {
		if (kv == null) return Promise.resolve(null);

		return kv.set(k, v);
	}

	private function get(k: String): Promise<Null<String>> {
		if (kv == null) return Promise.resolve(null);

		return kv.get(k);
	}
}
