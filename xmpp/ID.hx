package xmpp;

import haxe.crypto.Base64;
import haxe.io.Bytes;

#if nodejs
import js.node.Crypto;
#end

class ID {
	public static function tiny():String {
		return Base64.urlEncode(getRandomBytes(3));
	}

	public static function short():String {
		return Base64.urlEncode(getRandomBytes(9));
	}

	public static function medium():String {
		return Base64.urlEncode(getRandomBytes(18));
	}

	public static function long():String {
		return Base64.urlEncode(getRandomBytes(27));
	}

#if nodejs
	private static function getRandomBytes(n:Int):Bytes {
		return Crypto.randomBytes(n).hxToBytes();
	}
#elseif js
	private static function getRandomBytes(n:Int):Bytes {
		var array = new js.lib.Uint8Array(n);
		js.Browser.window.crypto.getRandomValues(array);
		return Bytes.ofData(array.buffer);
	}
#end

}
