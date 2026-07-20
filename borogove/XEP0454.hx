package borogove;

import haxe.io.Bytes;
import thenshim.Promise;

using StringTools;

function fetch(aesgcm: AesGcm, hash: Null<Hash> = null): Promise<Bytes> {
	// Fetch all data into memory because AES-GCM APIs really want to verify
	// everything before giving access to plaintext.
	// TODO: This means we ought to refuse to download if the size is too big:
	// https://github.com/haxetink/tink_http/issues/159
	return new Promise((resolve, reject) -> {
		tink.http.Client.fetch(aesgcm.https).all().handle((o) -> switch o {
			case Success(res):
				resolve(res.body);
			case Failure(e):
				reject(e);
		});
	}).then((encrypted) -> {
		if (hash != null) {
			final compare = Hash.mk(hash.algorithm, encrypted);
			if (compare != null && !hash.equals(compare)) {
				throw "Hash mismatch: " + hash + " != " + compare;
			}
		}

		#if js
		final subtle: js.html.SubtleCrypto = untyped globalThis.crypto.subtle;
		return (subtle.importKey("raw", aesgcm.key.getData(), "AES-GCM", false, ["decrypt"]).then(key ->
			subtle.decrypt({ name: "AES-GCM", iv: aesgcm.iv.getData() }, key, encrypted.toBytes().getData())
		).then(decrypted -> Bytes.ofData(decrypted)) : Promise<Bytes>);
		#else
		final aes = new haxe.crypto.Aes(aesgcm.key, aesgcm.iv);
		return aes.decrypt(haxe.crypto.mode.Mode.GCM, encrypted, Bytes.alloc(0));
		#end
	});
}

typedef AesGcm = {
	https: String,
	iv: haxe.io.Bytes,
	key: haxe.io.Bytes,
	mime: String
}

function parse(uriStr: String) : Null<AesGcm> {
	final uri = parseURI(uriStr);
	if (uri == null) return null;

	final https = "https:" + uri.rest;
	final ext = haxe.io.Path.extension(uri.rest);
	final iv = Bytes.ofHex(uri.fragment.substr(0, 24));
	final key = Bytes.ofHex(uri.fragment.substr(24));

	// There is no info about mime with XEP0454 so infer from extension...
	final mime = switch (ext) {
	case "jpg": "image/jpeg";
	case "png": "image/png";
	default: "application/octet-stream";
	};

	return { https: https, iv: iv, key: key, mime: mime };
}

private typedef SplitURI = {
	rest: String,
	fragment: String
}

private function parseURI(uriStr: String) : Null<SplitURI> {
	var r = ~/^aesgcm:(\/\/[^#]+)#(.{88})$/;
	if (!r.match(uriStr)) return null;

	var frag = r.matched(2);
	return {
		rest     : r.matched(1),
		fragment : frag != null ? frag : ""
	};
}
