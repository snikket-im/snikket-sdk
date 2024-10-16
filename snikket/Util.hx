package snikket;

// Std.downcast doesn't play well with null safety
function downcast<T, S>(value: T, c: Class<S>): Null<S> {
	return cast Std.downcast(cast value, cast c);
}
