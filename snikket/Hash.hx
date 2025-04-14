package snikket;

import haxe.crypto.Sha1;
import haxe.crypto.Sha256;
import haxe.crypto.Base64;
import haxe.io.Bytes;
import haxe.io.BytesData;
using StringTools;

import snikket.Config;

#if cpp
import HaxeCBridge;
#end

@:expose
@:nullSafety(Strict)
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Hash {
	public final algorithm: String;
	@:allow(snikket)
	private final hash: BytesData;

	@:allow(snikket)
	private function new(algorithm: String, hash: BytesData) {
		this.algorithm = algorithm;
		this.hash = hash;
	}

	public static function fromHex(algorithm: String, hash: String): Null<Hash> {
		try {
			return new Hash(algorithm, Bytes.ofHex(hash).getData());
		} catch (e) {
			return null;
		}
	}

	public static function fromUri(uri: String): Null<Hash> {
		if (uri.startsWith("cid:") && uri.endsWith("@bob.xmpp.org") && uri.contains("+")) {
			final parts = uri.substr(4).split("@")[0].split("+");
			final algo = parts[0] == "sha1" ? "sha-1" : parts[0];
			return Hash.fromHex(algo, parts[1]);
		} if (uri.startsWith("ni:///") && uri.contains(";")) {
			final parts = uri.substring(6).split(';');
			return new Hash(parts[0], Base64.urlDecode(parts[1]).getData());
		} else if (uri.startsWith("/.well-known/ni/")) {
			final parts = uri.substring(16).split('/');
			return new Hash(parts[0], Base64.urlDecode(parts[1]).getData());
		}

		return null;
	}

	@:allow(snikket)
	private static function sha1(bytes: Bytes) {
		return new Hash("sha-1", Sha1.make(bytes).getData());
	}

	@:allow(snikket)
	private static function sha256(bytes: Bytes) {
		return new Hash("sha-256", Sha256.make(bytes).getData());
	}

	public function toUri() {
		if (Config.relativeHashUri) {
			return "/.well-known/ni/" + algorithm.urlEncode() + "/" + toBase64Url();
		} else {
			return serializeUri();
		}
	}

	@:allow(snikket)
	private function bobUri() {
		return "cid:" + (algorithm == "sha-1" ? "sha1" : algorithm.urlEncode()) + "+" + toHex() + "@bob.xmpp.org";
	}

	@:allow(snikket)
	private function serializeUri() {
		return "ni:///" + algorithm.urlEncode() + ";" + toBase64Url();
	}

	public function toHex() {
		return Bytes.ofData(hash).toHex();
	}

	public function toBase64() {
		return Base64.encode(Bytes.ofData(hash), true);
	}

	public function toBase64Url() {
		return Base64.urlEncode(Bytes.ofData(hash));
	}
}
