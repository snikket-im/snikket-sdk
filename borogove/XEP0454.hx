package borogove;

import haxe.io.Bytes;
import thenshim.Promise;

using StringTools;

function fetch(aesgcm: AesGcm): Promise<Bytes> {
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

function put(source: tink.io.Source.RealSource, httpPut: (tink.io.Source.RealSource, Int)->Promise<String>): Promise<{ uri: String, size: Int }> {
	final iv = haxe.crypto.random.SecureRandom.bytes(12);
	final key = haxe.crypto.random.SecureRandom.bytes(32);

	return new Promise((resolve, reject) -> {
		tink.io.Source.RealSourceTools.all(source).handle(o -> switch o {
			case Success(bytes): resolve((bytes : Bytes));
			case Failure(e): reject(e);
		});
	}).then(bytes -> {
		#if js
		final subtle: js.html.SubtleCrypto = untyped globalThis.crypto.subtle;
		final encryptedP: Promise<Bytes> = subtle.importKey("raw", key.getData(), "AES-GCM", false, ["encrypt"]).then(key ->
			subtle.encrypt({ name: "AES-GCM", iv: iv.getData() }, key, bytes.getData())
		).then(encrypted -> Bytes.ofData(encrypted));
		#else
		final aes = new haxe.crypto.Aes(key, iv);
		final encryptedP = Promise.resolve(aes.encrypt(haxe.crypto.mode.Mode.GCM, bytes, Bytes.alloc(0), 16));
		#end
		return encryptedP.then(encrypted -> httpPut(encrypted, encrypted.length).then(uri -> ({ uri: ~/^https?:\/\//.map(uri, _ -> "aesgcm://") + "#" + iv.toHex() + key.toHex(), size: encrypted.length })));
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
