package snikket;

@:forward
abstract AttachmentSource(js.html.File) {
	public inline function tinkSource() {
		return tink.io.Source.ofJsFile(this.name, this);
	}
}
