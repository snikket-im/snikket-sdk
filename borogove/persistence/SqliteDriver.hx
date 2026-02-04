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

	public function new(dbfile: String, migrate: (Array<String>->Promise<haxe.iterators.ArrayIterator<Dynamic>>)->Promise<Any>) {
		this.dbfile = dbfile;
		readPool = Config.constrainedMemoryMode ? writePool : new sys.thread.ElasticThreadPool(10);
		ready = new Promise((resolve, reject) -> setReady = resolve);

		writePool.run(() -> {
			final db = sys.db.Sqlite.open(dbfile);
			db.request("PRAGMA journal_mode=WAL");
			db.request("PRAGMA temp_store=2");
			if (Config.constrainedMemoryMode) db.request("PRAGMA cache_size=0");
			dbs.push(db);
			migrate((sql) -> this.execute(writePool, sql.map(q -> { sql: q, params: [] }))).then(_ -> {
				setReady(true);
			});
		});
	}

	private function execute(pool: sys.thread.IThreadPool, qs: Array<{ sql: String, ?params: Array<Dynamic> }>) {
		return new Promise((resolve, reject) -> {
			pool.run(() -> {
				var db = dbs.pop(false);
				try {
					if (db == null) {
						db = sys.db.Sqlite.open(dbfile);
					}
					var result = null;
					for (q in qs) {
						final prepared = Sqlite.prepare(q);
						result = db.request(prepared);
					}
					// In testing, not copying to an array here caused BAD ACCESS sometimes
					// Though from sqlite docs it seems like it should be safe?
					final arr = { iterator: () -> result }.array();
					dbs.push(db);
					resolve(arr.iterator());
				} catch (e) {
					dbs.push(db);
					reject(e);
				}
			});
		});
	}


	public function execMany(qs: Array<{ sql: String, ?params: Array<Dynamic> }>) {
		return ready.then(_ -> {
			final pool = StringTools.startsWith(qs[0].sql, "SELECT") ? readPool : writePool;
			return execute(pool, qs);
		});
	}

	public function exec(sql: String, ?params: Array<Dynamic>) {
		return execMany([{ sql: sql, params: params }]);
	}
}
