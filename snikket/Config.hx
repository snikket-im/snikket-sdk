package snikket;

@:expose
class Config {
	/**
		Produce /.well-known/ni/ paths instead of ni:/// URIs
		for referencing media by hash.

		This can be useful eg for intercepting with a Service Worker.
	**/
	public static var relativeHashUri = false;
}
