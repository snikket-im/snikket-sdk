package snikket;

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

	public function new(path: String, mime: String) {
		this.name = haxe.io.Path.withoutDirectory(path);
		this.path = sys.FileSystem.fullPath(path);
		this.size = sys.FileSystem.stat(this.path).size;
		this.type = mime;
	}

	@:allow(snikket)
	private inline function tinkSource() {
		return tink.io.Source.ofInput(this.name, sys.io.File.read(path));
	}
}
