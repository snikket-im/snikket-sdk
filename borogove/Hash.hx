package borogove;

import haxe.crypto.Sha1;
import haxe.crypto.Sha256;
import haxe.crypto.Base64;
import haxe.io.Bytes;
import haxe.io.BytesData;
using StringTools;

import borogove.Config;

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
	/**
		Hash algorithm name
	**/
	public final algorithm: String;
	@:allow(borogove)
	private final hash: BytesData;

	@:allow(borogove)
	private function new(algorithm: String, hash: BytesData) {
		this.algorithm = algorithm;
		this.hash = hash;
	}

	/**
		Create a new Hash from a hex string

		@param algorithm name per https://xmpp.org/extensions/xep-0300.html
		@param hash in hex format
		@returns Hash or null on error
	**/
	public static function fromHex(algorithm: String, hash: String): Null<Hash> {
		try {
			return new Hash(algorithm, Bytes.ofHex(hash).getData());
		} catch (e) {
			return null;
		}
	}

	/**
		Create a new Hash from a ni:, cid: or similar URI

		@param uri The URI
		@returns Hash or null on error
	**/
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

	@:allow(borogove)
	private static function sha1(bytes: Bytes) {
		return new Hash("sha-1", Sha1.make(bytes).getData());
	}

	@:allow(borogove)
	private static function sha256(bytes: Bytes) {
		return new Hash("sha-256", Sha256.make(bytes).getData());
	}

	/**
		Represent this Hash as a URI

		@returns URI as a string
	**/
	public function toUri() {
		if (Config.relativeHashUri) {
			return "/.well-known/ni/" + algorithm.urlEncode() + "/" + toBase64Url();
		} else {
			return serializeUri();
		}
	}

	@:allow(borogove)
	private function bobUri() {
		return "cid:" + (algorithm == "sha-1" ? "sha1" : algorithm.urlEncode()) + "+" + toHex() + "@bob.xmpp.org";
	}

	@:allow(borogove)
	private function serializeUri() {
		return "ni:///" + algorithm.urlEncode() + ";" + toBase64Url();
	}

	/**
		Represent this Hash as a hex string

		@returns hex string
	**/
	public function toHex() {
		return Bytes.ofData(hash).toHex();
	}

	/**
		Represent this Hash as a Base64 string

		@returns Base64-encoded string
	**/
	public function toBase64() {
		return Base64.encode(Bytes.ofData(hash), true);
	}

	/**
		Represent this Hash as a Base64url string

		@returns Base64url-encoded string
	**/
	public function toBase64Url() {
		return Base64.urlEncode(Bytes.ofData(hash));
	}
}
