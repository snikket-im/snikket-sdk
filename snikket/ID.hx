package snikket;

import hx.strings.RandomStrings;

class ID {
	public static function tiny():String {
		return RandomStrings.randomAsciiAlphaNumeric(6);
	}

	public static function short():String {
		return RandomStrings.randomAsciiAlphaNumeric(18);
	}

	public static function medium():String {
		return RandomStrings.randomAsciiAlphaNumeric(32);
	}

	public static function long():String {
		return RandomStrings.randomUUIDv4();
	}
}
