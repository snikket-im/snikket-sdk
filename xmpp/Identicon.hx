package xmpp;

import xmpp.Color;
import haxe.crypto.Sha1;
import haxe.io.Bytes;
import haxe.io.BytesInput;

@:expose
class Identicon {
	public static function svg(source: String) {
		final sha = Sha1.make(Bytes.ofString(source));
		final input = new BytesInput(sha);
		input.bigEndian = true;
		final hash = input.readInt32();
		var uri = 'data:image/svg+xml,<svg%20xmlns="http://www.w3.org/2000/svg"%20version="1.1"%20width="5"%20height="5"%20viewBox="0%200%205%205">';
		uri += "<style>rect{fill:%23" + Color.forString(source).substr(1) + ";}</style>";
		var i = 0;
		for (x in 0...3) {
			for (y in 0...5) {
				final value = hash >> (i++);
				if (value % 2 == 0) {
					uri += "<rect%20width=\"1\"%20height=\"1\"%20x=\"" + x + "\"%20y=\"" + y + "\"/>";
					if (x != 2) {
						uri += "<rect%20width=\"1\"%20height=\"1\"%20x=\"" + (4 - x) + "\"%20y=\"" + y + "\"/>";
					}
				}
			}
		}
		return uri + "</svg>";
	}
}
