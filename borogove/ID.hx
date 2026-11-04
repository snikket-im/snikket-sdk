package borogove;

import hx.strings.RandomStrings;
import UUIDv7;

class ID {
	public static inline function unique():String {
		return uuidv7();
	}

	/*
		For when a uuid would be too big to fit
	*/
	public static function random(len: Int):String {
		return RandomStrings.randomAsciiAlphaNumeric(len);
	}
}
