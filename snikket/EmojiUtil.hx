/*
 * Copyright (c) 2017, Daniel Gultsch All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 * list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation and/or
 * other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors
 * may be used to endorse or promote products derived from this software without
 * specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

package snikket;

class EmojiUtil {

	public static final MISC_SYMBOLS_AND_PICTOGRAPHS = new UnicodeRange(0x1F300, 0x1F5FF);
	public static final SUPPLEMENTAL_SYMBOLS = new UnicodeRange(0x1F900, 0x1F9FF);
	public static final EMOTICONS = new UnicodeRange(0x1F600, 0x1FAF6);
	//public static final UnicodeRange TRANSPORT_SYMBOLS = new UnicodeRange(0x1F680, 0x1F6FF);
	public static final MISC_SYMBOLS = new UnicodeRange(0x2600, 0x26FF);
	public static final DINGBATS = new UnicodeRange(0x2700, 0x27BF);
	public static final ENCLOSED_ALPHANUMERIC_SUPPLEMENT = new UnicodeRange(0x1F100, 0x1F1FF);
	public static final ENCLOSED_IDEOGRAPHIC_SUPPLEMENT = new UnicodeRange(0x1F200, 0x1F2FF);
	public static final REGIONAL_INDICATORS = new UnicodeRange(0x1F1E6, 0x1F1FF);
	public static final GEOMETRIC_SHAPES = new UnicodeRange(0x25A0, 0x25FF);
	public static final LATIN_SUPPLEMENT = new UnicodeRange(0x80, 0xFF);
	public static final MISC_TECHNICAL = new UnicodeRange(0x2300, 0x23FF);
	public static final TAGS = new UnicodeRange(0xE0020, 0xE007F);
	public static final CYK_SYMBOLS_AND_PUNCTUATION = new UnicodeList(0x3030, 0x303D);
	public static final LETTERLIKE_SYMBOLS = new UnicodeList(0x2122, 0x2139);

	public static final KEYCAP_COMBINEABLE = new UnicodeBlocks(new UnicodeList(0x23), new UnicodeList(0x2A), new UnicodeRange(0x30, 0x39));

	public static final SYMBOLIZE = new UnicodeBlocks(
			GEOMETRIC_SHAPES,
			LATIN_SUPPLEMENT,
			CYK_SYMBOLS_AND_PUNCTUATION,
			LETTERLIKE_SYMBOLS,
			KEYCAP_COMBINEABLE);
	public static final EMOJIS = new UnicodeBlocks(
			MISC_SYMBOLS_AND_PICTOGRAPHS,
			SUPPLEMENTAL_SYMBOLS,
			EMOTICONS,
			//TRANSPORT_SYMBOLS,
			MISC_SYMBOLS,
			DINGBATS,
			ENCLOSED_ALPHANUMERIC_SUPPLEMENT,
			ENCLOSED_IDEOGRAPHIC_SUPPLEMENT,
			MISC_TECHNICAL);

	public static final MAX_EMOIJS = 42;

	public static final ZWJ = 0x200D;
	public static final VARIATION_16 = 0xFE0F;
	public static final COMBINING_ENCLOSING_KEYCAP = 0x20E3;
	public static final BLACK_FLAG = 0x1F3F4;
	public static final FITZPATRICK = new UnicodeRange(0x1F3FB, 0x1F3FF);

	private static function parse(str: String) {
		final symbols = [];
		var builder = new Builder();
		var needsFinalBuild = false;
		final input = StringUtil.rawCodepointArray(str);
		for (i in 0...input.length) {
			final cp = input[i];
			if (builder.offer(cp)) {
				needsFinalBuild = true;
			} else {
				symbols.push(builder.build());
				builder = new Builder();
				if (builder.offer(cp)) {
					needsFinalBuild = true;
				}
			}
		}
		if (needsFinalBuild) {
			symbols.push(builder.build());
		}
		return symbols;
	}

	public static function isEmoji(input: String) {
		final symbols = parse(input);
		return symbols.length == 1 && symbols[0].isEmoji();
	}

	public static function isOnlyEmoji(input: String) {
		final symbols = parse(input);
		for (symbol in symbols) {
			if (!symbol.isEmoji()) {
				return false;
			}
		}
		return symbols.length > 0;
	}
}

abstract class Symbol {
	private final value: String;

	public function new(codepoints: Array<Int>) {
		final builder = new StringBuf();
		for (codepoint in codepoints) {
			builder.addChar(codepoint);
		}
		this.value = builder.toString();
	}

	public abstract function isEmoji():Bool;

	public function toString() {
		return value;
	}
}

class Emoji extends Symbol {
	public function new(codepoints: Array<Int>) {
		super(codepoints);
	}

	public function isEmoji() {
		return true;
	}
}

class Other extends Symbol {
	public function new(codepoints: Array<Int>) {
		super(codepoints);
	}

	public function isEmoji() {
		return false;
	}
}

class Builder {
	private final codepoints = [];

	public function new() {}

	public function offer(codepoint: Int) {
		var add = false;
		if (this.codepoints.length == 0) {
			if (EmojiUtil.SYMBOLIZE.contains(codepoint)) {
				add = true;
			} else if (EmojiUtil.REGIONAL_INDICATORS.contains(codepoint)) {
				add = true;
			} else if (EmojiUtil.EMOJIS.contains(codepoint) && !EmojiUtil.FITZPATRICK.contains(codepoint) && codepoint != EmojiUtil.ZWJ) {
				add = true;
			}
		} else {
			var previous = codepoints[codepoints.length - 1];
			if (codepoints[0] == EmojiUtil.BLACK_FLAG) {
				add = EmojiUtil.TAGS.contains(codepoint);
			} else if (EmojiUtil.COMBINING_ENCLOSING_KEYCAP == codepoint) {
				add = EmojiUtil.KEYCAP_COMBINEABLE.contains(previous) || previous == EmojiUtil.VARIATION_16;
			} else if (EmojiUtil.SYMBOLIZE.contains(previous)) {
				add = codepoint == EmojiUtil.VARIATION_16;
			} else if (EmojiUtil.REGIONAL_INDICATORS.contains(previous) && EmojiUtil.REGIONAL_INDICATORS.contains(codepoint)) {
				add = codepoints.length == 1;
			} else if (previous == EmojiUtil.VARIATION_16) {
				add = isMerger(codepoint) || codepoint == EmojiUtil.VARIATION_16;
			} else if (EmojiUtil.FITZPATRICK.contains(previous)) {
				add = codepoint == EmojiUtil.ZWJ;
			} else if (EmojiUtil.ZWJ == previous) {
				add = EmojiUtil.EMOJIS.contains(codepoint);
			} else if (isMerger(codepoint)) {
				add = true;
			} else if (codepoint == EmojiUtil.VARIATION_16 && EmojiUtil.EMOJIS.contains(previous)) {
				add = true;
			}
		}
		if (add) {
			codepoints.push(codepoint);
			return true;
		} else {
			return false;
		}
	}

	private static function isMerger(codepoint: Int) {
		return codepoint == EmojiUtil.ZWJ || EmojiUtil.FITZPATRICK.contains(codepoint);
	}

	public function build(): Symbol {
		if (codepoints.length > 0 && EmojiUtil.SYMBOLIZE.contains(codepoints[codepoints.length - 1])) {
			return new Other(codepoints);
		} else if (codepoints.length > 1 && EmojiUtil.KEYCAP_COMBINEABLE.contains(codepoints[0]) && codepoints[codepoints.length - 1] != EmojiUtil.COMBINING_ENCLOSING_KEYCAP) {
			return new Other(codepoints);
		}
		return codepoints.length == 0 ? new Other(codepoints) : new Emoji(codepoints);
	}
}

class UnicodeBlocks implements UnicodeSet {
	final unicodeSets: Array<UnicodeSet>;

	public function new(...sets: UnicodeSet) {
		this.unicodeSets = sets;
	}

	public function contains(codepoint: Int) {
		for (unicodeSet in unicodeSets) {
			if (unicodeSet.contains(codepoint)) {
				return true;
			}
		}
		return false;
	}
}

interface UnicodeSet {
	public function contains(codepoint: Int):Bool;
}

class UnicodeList implements UnicodeSet {
	final list: Array<Int>;

	public function new(...codes: Int) {
		this.list = codes;
	}

	public function contains(codepoint: Int) {
		return this.list.contains(codepoint);
	}
}

class UnicodeRange implements UnicodeSet {
	private final lower: Int;
	private final upper: Int;

	public function new(lower: Int, upper: Int) {
		this.lower = lower;
		this.upper = upper;
	}

	public function contains(codePoint: Int) {
		return codePoint >= lower && codePoint <= upper;
	}
}
