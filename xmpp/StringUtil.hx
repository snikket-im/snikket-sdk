package xmpp;

class StringUtil {
	@:access(StringTools)
	public static function codepointArray(s: String) {
		final result = [];
		var offset = 0;
		while (offset < s.length) {
		#if utf16
			final c = StringTools.utf16CodePointAt(s, offset);
			if (c >= StringTools.MIN_SURROGATE_CODE_POINT) {
				result.push(s.substr(offset, 2));
				offset++;
			} else {
				result.push(s.substr(offset, 1));
			}
			offset++;
		#else
			result.push(s.substr(offset, 1));
			offset++;
		#end
		}
		return result;
	}
}
