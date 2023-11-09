package xmpp;

import hsluv.Hsluv;
import haxe.io.Bytes;
import haxe.crypto.Sha1;

class Color {
	public static function forString(s:String) {
		var hash = Sha1.make(Bytes.ofString(s));
		var hue = (hash.getUInt16(0) / 65536.0) * 360;
		var color = new Hsluv();
		color.hsluv_h = hue;
		color.hsluv_s = 100;
		color.hsluv_l = 50;
		color.hsluvToHex();
		return color.hex;
	}

	public static function defaultPhoto(input:String, letter:String) {
		var hex = forString(input).substr(1);
		return
			'data:image/svg+xml,<svg%20xmlns="http://www.w3.org/2000/svg"%20version="1.1"%20width="15"%20height="15"%20viewBox="0%200%2015%2015">' +
			'<rect%20style="fill:%23' + hex + ';"%20width="15"%20height="15"%20x="0"%20y="0"%20/>' +
			'<text%20style="fill:%23ffffff;font-size:8px;font-family:sans-serif;"%20text-anchor="middle"%20dominant-baseline="central"%20x="50%25"%20y="50%25">' + StringTools.urlEncode(letter) + '</text>' +
			'</svg>';
	}
}
