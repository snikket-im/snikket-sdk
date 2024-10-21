package snikket;

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

// Std.downcast doesn't play well with null safety
function downcast<T, S>(value: T, c: Class<S>): Null<S> {
	return cast Std.downcast(cast value, cast c);
}
