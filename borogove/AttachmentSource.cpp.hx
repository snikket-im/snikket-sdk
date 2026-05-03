package borogove;

#if cpp
import HaxeCBridge;
#end

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class AttachmentSource {
	public final path: String;
	public final type: String;
	public final name: String;
	public final size: Int;

	/**
		Create an attachment source from a local file path and MIME type.

		@param path path to the local file
		@param mime MIME type to advertise for the upload
	**/
	public function new(path: String, mime: String) {
		this.name = haxe.io.Path.withoutDirectory(path);
		this.path = sys.FileSystem.fullPath(path);
		this.size = sys.FileSystem.stat(this.path).size;
		this.type = mime;
	}

	@:allow(borogove)
	private inline function tinkSource() {
		return tink.io.Source.ofInput(this.name, sys.io.File.read(path));
	}
}
