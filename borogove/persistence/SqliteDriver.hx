package borogove.persistence;

import haxe.io.Bytes;
import thenshim.Promise;
import sys.db.Connection;
using Lambda;

class SqliteDriver {
	final dbs: sys.thread.Deque<Connection> = new sys.thread.Deque();
	private final writePool: sys.thread.IThreadPool = new sys.thread.FixedThreadPool(1);
	private final readPool: sys.thread.IThreadPool;
	private final dbfile: String;
	private final ready: Promise<Bool>;
	private var setReady: (Bool)->Void;
	private var mainLoop: sys.thread.EventLoop;

	public function new(dbfile: String, migrate: (Array<String>->Promise<haxe.iterators.ArrayIterator<Dynamic>>)->Promise<Any>) {
		this.dbfile = dbfile;
		readPool = Config.constrainedMemoryMode ? writePool : new sys.thread.ElasticThreadPool(10);
		ready = new Promise((resolve, reject) -> setReady = resolve);
		mainLoop = sys.thread.Thread.current().events;

		writePool.run(() -> {
			final db = sys.db.Sqlite.open(dbfile);
			db.request("PRAGMA journal_mode=WAL");
			dbs.push(db);
			migrate((sql) -> this.execute(writePool, sql, [])).then(_ -> {
				setReady(true);
			});
		});
	}

	private function execute(pool: sys.thread.IThreadPool, qs: Array<String>, params: Array<Dynamic>) {
		return new Promise((resolve, reject) -> {
			pool.run(() -> {
				var db = dbs.pop(false);
				try {
					if (db == null) {
						db = sys.db.Sqlite.open(dbfile);
					}
					var result = null;
					for (q in qs) {
						if (result == null) {
							final prepared = prepare(db, q, params);
							result = db.request(prepared);
						} else {
							db.request(q);
						}
					}
					// In testing, not copying to an array here caused BAD ACCESS sometimes
					// Though from sqlite docs it seems like it should be safe?
					final arr = { iterator: () -> result }.array();
					dbs.push(db);
					mainLoop.run(() -> { resolve(arr.iterator()); });
				} catch (e) {
					dbs.push(db);
					mainLoop.run(() -> reject(e));
				}
			});
		});
	}

	public function exec(sql: haxe.extern.EitherType<String, Array<String>>, ?params: Array<Dynamic>) {
		return ready.then(_ -> {
			final qs = Std.isOfType(sql, String) ? [sql] : sql;
			final pool = StringTools.startsWith(qs[0], "SELECT") ? readPool : writePool;
			return execute(pool, qs, params ?? []);
		});
	}

	private function prepare(db: Connection, sql:String, params: Array<Dynamic>): String {
		return ~/\?/gm.map(sql, f -> {
			var p = params.shift();
			return switch (Type.typeof(p)) {
				case TClass(String):
					db.quote(p);
				case TBool:
					p == true ? "1" : "0";
				case TFloat:
					Std.string(p);
				case TInt:
					Std.string(p);
				case TNull:
					"NULL";
				case TClass(Array):
					var bytes:Bytes = Bytes.ofData(p);
					"X'" + bytes.toHex() + "'";
				case TClass(haxe.io.Bytes):
					var bytes:Bytes = cast p;
					"X'" + bytes.toHex() + "'";
				case _:
					throw("UKNONWN: " + Type.typeof(p));
			}
		});
	}
}
