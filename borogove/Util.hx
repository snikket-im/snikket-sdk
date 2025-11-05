package borogove;

import haxe.io.Bytes;
#if js
import js.html.TextEncoder;
final textEncoder = new TextEncoder();
#end

function setupTrace() {
#if js
	haxe.Log.trace = (v, ?infos) -> {
		if (js.Syntax.typeof(untyped console) != "undefined" && (untyped console).debug != null) {
			final params = infos.customParams ?? [];
			infos.customParams = [];
			final str: Dynamic = haxe.Log.formatOutput(v, infos);
			(untyped console).debug.apply(null, [str].concat(params));
		} else if (js.Syntax.typeof(untyped console) != "undefined" && (untyped console).log != null) {
			final str = haxe.Log.formatOutput(v, infos);
			(untyped console).log(str);
		}
	}
#end
}

inline function bytesOfString(s: String) {
#if js
	return Bytes.ofData(textEncoder.encode(s).buffer);
#else
	return Bytes.ofString(s);
#end
}

// Faster just by specializing to array
inline function existsFast<A>(it:Array<A>, f:(item:A) -> Bool) {
	var result = false;
	for (x in it) {
		if (f(x)) {
			result = true;
			break;
		}
	}
	return result;
}

@:nullSafety(Strict)
inline function findFast<T>(it:Array<T>, f:(item:T) -> Bool):Null<T> {
	var result = null;
	for (v in it) {
		if (f(v)) {
			result = v;
			break;
		}
	}
	return result;
}

// Std.downcast doesn't play well with null safety
function downcast<T, S>(value: T, c: Class<S>): Null<S> {
	return cast Std.downcast(cast value, cast c);
}

function xmlEscape(s: String) {
	// NOTE: using StringTools.htmlEscape breaks things if this is one half of a surrogate pair in an adjacent cdata
	return StringTools.replace(StringTools.replace(StringTools.replace(s, "&", "&amp;"), "<", "&lt;"), ">", "&gt;");
}

macro function getGitVersion():haxe.macro.Expr.ExprOf<String> {
	#if !display
	var process = new sys.io.Process('git', ['describe', '--always']);
	if (process.exitCode() != 0) {
		var message = process.stderr.readAll().toString();
		var pos = haxe.macro.Context.currentPos();
		haxe.macro.Context.error("Cannot execute `git describe`. " + message, pos);
	}

	// read the output of the process
	var commitHash:String = process.stdout.readLine();

	// Generates a string expression
	return macro $v{commitHash};
	#else
	// `#if display` is used for code completion. In this case returning an
	// empty string is good enough; We don't want to call git on every hint.
	var commitHash:String = "";
	return macro $v{commitHash};
	#end
}

class Util {
	inline static public function at<T>(arr: Array<T>, i: Int): T {
		return arr[i];
	}

	inline static public function writeS(o: haxe.io.Output, s: String) {
		final b = bytesOfString(s);
		o.writeBytes(b, 0, b.length);
	}
}
