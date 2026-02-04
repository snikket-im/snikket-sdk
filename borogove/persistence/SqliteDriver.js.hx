package borogove.persistence;

import haxe.io.Bytes;
import thenshim.Promise;

typedef Promiser = (String, Dynamic) -> Promise<Dynamic>;

#if nodejs
class SqliteDriver {
	public function new(dbfile: String, migrate: (Array<String>->Promise<haxe.iterators.ArrayIterator<Dynamic>>)->Promise<Any>) {
		throw "TODO";
	}

	public function exec(sql: haxe.extern.EitherType<String, Array<String>>, ?params: Array<Dynamic>): Promise<haxe.iterators.ArrayIterator<Dynamic>> {
		throw "TODO";
	}
}
#else
@:js.import("@sqlite.org/sqlite-wasm", "sqlite3Worker1Promiser")
extern class Worker1 {
	static var v2: ({ worker: () -> js.html.Worker }) -> Promise<Promiser>;
}

class SqliteDriver {
	private var sqlite: Promiser;
	private var dbId: String;

	public function new(dbfile: String, migrate: (Array<String>->Promise<haxe.iterators.ArrayIterator<Dynamic>>)->Promise<Any>) {
		Worker1.v2({
			worker: () -> new js.html.Worker(
				untyped new js.html.URL("sqlite-worker1.mjs", js.Syntax.code("import.meta.url")),
				untyped { type: "module" }
			)
		}).then(promiser -> {
			sqlite = promiser;
			return sqlite("open", { filename: dbfile, vfs: "opfs-sahpool" });
		}).then(openResult -> {
			dbId = openResult.dbId;
			return migrate((sql) -> this.execMany(sql.map(q -> { sql: q, params: [] })));
		});
	}

	public function execMany(qs: Array<{ sql: String, ?params: Array<Dynamic> }>): Promise<haxe.iterators.ArrayIterator<Dynamic>> {
		if (sqlite == null || dbId == null) {
			// Not ready yet
			return new Promise((resolve, reject) -> haxe.Timer.delay(() -> resolve(null), 100))
				.then(_ -> execMany(qs));
		}

		final first = qs.shift();
		final sql = qs.map(q -> Sqlite.prepare(q) + ";");
		final items: Array<Dynamic> = [];
		var signalAllDone;
		final allDone = new Promise((resolve, reject) -> signalAllDone = resolve);
		return sqlite('exec', {
			dbId: dbId,
			sql: [first.sql + ";"].concat(sql),
			bind: (first.params ?? []).map(formatParam),
			rowMode: "object",
			callback: (r) -> {
				if (r.rowNumber == null) {
					signalAllDone(null);
				} else {
					items.push(r.row);
				}
				null;
			}
		}).then(_ -> allDone).then(_ -> items.iterator());
	}

	public function exec(sql: String, ?params: Array<Dynamic>) {
		return execMany([{ sql: sql, params: params }]);
	}

	private function formatParam(p: Dynamic): Dynamic {
		return switch (Type.typeof(p)) {
			case TClass(haxe.io.Bytes):
				var bytes:Bytes = cast p;
				return bytes.getData();
			case _:
				return p;
		}
	}
}
#end
