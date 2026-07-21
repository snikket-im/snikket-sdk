package borogove;

import haxe.io.Bytes;
import thenshim.Promise;
import tink.io.Source;

#if js
@:native("ReadableStream")
extern class ReadableStream {
	public var __source: RealSource;
	public function new(o: { pull: ({ enqueue: (js.lib.Uint8Array->Void), close: ()->Void })->Promise<Any> });
}
typedef UnderlyingSource = ReadableStream;
#else
typedef UnderlyingSource = RealSource;
#end

abstract Source(UnderlyingSource) {
	private function new(source: UnderlyingSource) {
		this = source;
	}

	@:allow(borogove)
	@:to private inline function tinkSource(): RealSource {
		#if js
		return this.__source;
		#else
		return this;
		#end
	}

	@:from public static function ofTinkSource(source: RealSource) {
		#if js
		var stream: ReadableStream = null;
		stream = new ReadableStream({
			pull: (controller) -> {
				return new Promise((resolve, reject) -> {
					stream.__source.chunked().next().handle(o -> switch o {
						case End:
							controller.close();
							resolve(null);
						case Fail(e):
							reject(e);
						case Link(chunk, next):
							stream.__source = next;
							controller.enqueue(new js.lib.Uint8Array(chunk.toBytes().getData()));
							resolve(null);
					});
				});
			}
		});
		stream.__source = source;
		return new Source(stream);
		#else
		return new Source(source);
		#end
	}

	@:from static inline function ofString(s:String) {
		return ofTinkSource((s : RealSource));
	}

	@:from static inline function ofBytes(b:Bytes) {
		return ofTinkSource((b : RealSource));
	}
}
