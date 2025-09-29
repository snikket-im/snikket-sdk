package borogove;

import haxe.Constraints.IMap;
import js.lib.HaxeIterator;
import js.lib.Map as NativeMap;
using Lambda;

// Use ES6 maps instead of Haxe maps
@:forward
abstract Map<K,V>(NativeMap<K,V>) {
	public inline function set(k:K, v:V):Void {
		this.set(k, v);
	}

	public inline function get(k:K):Null<V> {
		return this.get(k);
	}

	public inline function exists(k:K):Bool {
		return this.has(k);
	}

	public inline function remove(k:K):Bool {
		return this.delete(k);
	}

	public inline function keys():Iterator<K> {
		return new HaxeIterator(this.keys());
	}

	public inline function iterator():Iterator<V> {
		return new HaxeIterator(this.values());
	}

	public inline function keyValueIterator():KeyValueIterator<K, V> {
		return new HaxeKVIterator(this.entries());
	}

	// This shouldn't be needed but complier wants it...
	public inline function flatMap<B>(f:(item:V)->Iterable<B>): Array<B> {
		return { iterator: () -> this.iterator() }.flatMap(f);
	}

	@:arrayAccess @:noCompletion public inline function arrayRead(k:K) {
		return this.get(k);
	}

	@:arrayAccess @:noCompletion public inline function arrayWrite(k:K, v:V):V {
		this.set(k, v);
		return v;
	}

	@:from static function fromMap<K,V>(map:haxe.ds.Map<K,V>):Map<K, V> {
		final result = new NativeMap();
		for (k => v in map) {
			result.set(k, v);
		}
		return cast result;
	}

	@:from static inline function fromArray<K,V>(iterable:Iterable<js.lib.KeyValue<K,V>>):Map<K, V> {
		return cast new NativeMap(iterable);
	}
}

class HaxeKVIterator<K,V> {
	final jsIterator: js.lib.Iterator<js.lib.KeyValue<K,V>>;
	var lastStep: js.lib.Iterator.IteratorStep<js.lib.KeyValue<K,V>>;

	public inline function new(jsIterator: js.lib.Iterator<js.lib.KeyValue<K,V>>) {
		this.jsIterator = jsIterator;
		lastStep = jsIterator.next();
	}

	public inline function hasNext(): Bool {
		return !lastStep.done;
	}

	public inline function next(): { key: K, value: V } {
		var v = lastStep.value;
		lastStep = jsIterator.next();
		return { key: v.key, value: v.value };
	}
}
