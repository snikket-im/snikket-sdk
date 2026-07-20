package borogove.persistence;

#if cpp
import HaxeCBridge;
#end
import haxe.io.Bytes;
import haxe.io.BytesData;
import sys.FileSystem;
import sys.io.File;
import tink.io.Source;
import tink.io.Sink;
import thenshim.Promise;

#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
@HaxeCBridge.name("borogove_persistence_media_store_fs")
#end
@:expose
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
	public function hasMedia(hash: Hash): Promise<Null<String>> {
		return getMediaPath(hash.toUri());
	}

	@HaxeCBridge.noemit
	public function removeMedia(hashAlgorithm: String, hash: BytesData) {
		final hash = new Hash(hashAlgorithm, hash);
		return getMediaPath(hash.toUri()).then((path) -> {
			if (path != null) FileSystem.deleteFile(path);
			return true;
		});
	}

	@HaxeCBridge.noemit
	public function storeMedia(mime: String, source: borogove.Source): Promise<String> {
		final sha1 = Hash.sha1incr();
		final sha256 = Hash.sha256incr();
		final tmpPath = blobpath + "/tmp" + ID.unique();
		final tmpFile = File.write(tmpPath);

		return new Promise((resolve, reject) -> {
			((source : RealSource).chunked().map((chunk) -> {
				sha1.update((chunk : Bytes).getData());
				sha256.update((chunk : Bytes).getData());
				return chunk;
			}) : RealSource).pipeTo(Sink.ofOutput("tmpPath", tmpFile)).handle(o -> switch o {
				case AllWritten:
					tmpFile.close();
					resolve(null);
				default: reject(o);
			});
		}).then(_ -> {
			final sha1h = sha1.digest();
			final sha256h = sha256.digest();
			final path = blobpath + "/f" + sha256h.toHex();
			sys.FileSystem.rename(tmpPath, path);
			return thenshim.PromiseTools.all([
				set(sha1h.serializeUri(), sha256h.serializeUri()),
				set(sha256h.serializeUri() + "#contentType", mime)
			]).then(_ -> path);
		});
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
