package borogove;

import hsluv.Hsluv;
import haxe.io.Bytes;
import haxe.crypto.Sha1;
import borogove.Util;

class Color {
	private static var cache: Map<String, String> = [];
	private static var cacheSize = 0;

	public static function forString(s:String) {
		final fromCache = cache[s];
		if (fromCache != null) return fromCache;

		var hash = Sha1.make(bytesOfString(s));
		var hue = (hash.getUInt16(0) / 65536.0) * 360;
		var color = new Hsluv();
		color.hsluv_h = hue;
		color.hsluv_s = 100;
		color.hsluv_l = 50;
		color.hsluvToHex();
		if (cacheSize < 2000) {
			cache[s] = color.hex;
			cacheSize++;
		}
		return color.hex;
	}

	public static function defaultPhoto(input:String, letter:String) {
		final hex = forString(input).substr(1);
		final encodedLetter = try {
			StringTools.urlEncode(letter.toUpperCase());
		} catch (e) {
			" ";
		}
		return
			'data:image/svg+xml,<svg%20xmlns="http://www.w3.org/2000/svg"%20version="1.1"%20width="15"%20height="15"%20viewBox="0%200%2015%2015">' +
			'<rect%20style="fill:%23' + hex + ';"%20width="15"%20height="15"%20x="0"%20y="0"%20/>' +
			'<text%20style="fill:%23ffffff;font-size:8px;font-family:sans-serif;"%20text-anchor="middle"%20x="7.5"%20y="10">' + encodedLetter + '</text>' +
			'</svg>';
	}
}
