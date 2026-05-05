package borogove.persistence;

import haxe.io.Bytes;
import thenshim.Promise;
using StringTools;

typedef Promiser = (String, Dynamic) -> Promise<Dynamic>;

#if nodejs
@:js.import("node:worker_threads", "Worker")
extern class Worker {
	public function new(code: String, options: { eval: Bool, workerData: Any });
	public function postMessage(data: Any): Void;
	public function on(event: String, handler: (Dynamic) -> Void): Void;
}

class SqliteDriver {
	static inline final WORKER = '
		import { workerData, parentPort } from "node:worker_threads";
		import { DatabaseSync } from "node:sqlite";
		const db = new DatabaseSync(workerData.dbfile);

		if (workerData.writer) {
			db.exec("PRAGMA journal_mode=WAL");
			db.exec("PRAGMA synchronous=NORMAL");
			db.exec("PRAGMA temp_store=2");
		}

		parentPort.on("message", ({ id, qs }) => {
			const lastQ = qs.pop();
			if (qs.length > 0) db.exec("BEGIN TRANSACTION");
			try {
				for (const q of qs) {
					db.exec(q);
				}
				parentPort.postMessage({ id, result: db.prepare(lastQ).all() });
				if (qs.length > 0) db.exec("COMMIT");
			} catch (error) {
				if (qs.length > 0) db.exec("ROLLBACK");
				parentPort.postMessage({ id, error });
			}
		});
	';
	private final writePool: Array<Worker> = [];
	private var readPool: Array<Worker> = [];
	private final pending: Map<Int, { resolve: (Array<Dynamic>) -> Void, reject: (Any) -> Void }> = new Map();
	private final ready: Promise<Bool>;
	private var setReady: (Bool)->Void;
	private var reqId = 0;

	private function mkWorker(dbfile: String, writer: Bool) {
		final worker = new Worker(WORKER, { eval: true, workerData: { dbfile: dbfile, writer: writer } });
		worker.on("message", (data: { id: Int, ?result: Array<Dynamic>, ?error: Any}) -> {
			if (data.error != null) {
				pending[data.id].reject(data.error);
			} else {
				pending[data.id].resolve(data.result);
			}
			pending.remove(data.id);
		});
		return worker;
	}

	public function new(dbfile: String, migrate: (Array<String>->Promise<haxe.iterators.ArrayIterator<Dynamic>>)->Promise<Any>) {
		ready = new Promise((resolve, reject) -> setReady = resolve);

		writePool.push(mkWorker(dbfile, true));
		if (~/:memory:|mode=memory/.match(dbfile)) {
			readPool = writePool;
		} else {
			for (i in 0...10) {
				readPool.push(mkWorker(dbfile, false));
			}
		}

		migrate((sql) -> this.execute(writePool, sql.map(q -> { sql: q, params: [] }))).then(_ -> {
			setReady(true);
		});
	}

	private function execute(pool: Array<Worker>, qs: Array<{ sql: String, ?params: Array<Dynamic> }>): Promise<haxe.iterators.ArrayIterator<Dynamic>> {
		final worker = pool.pop();
		if (worker == null) {
			return new Promise((resolve, reject) -> haxe.Timer.delay(() -> resolve(null), 10)).then(_ ->
				execute(pool, qs)
			);
		}
		final id = reqId++;
		final promise = new Promise((resolve, reject) -> pending[id] = { resolve: resolve, reject: reject });
		worker.postMessage({ id: id, qs: qs.map(q -> Sqlite.prepare(q)) });
		return promise.then(result -> {
			pool.push(worker);
			return result.iterator();
		});
	}

	public function execMany(qs: Array<{ sql: String, ?params: Array<Dynamic> }>): Promise<haxe.iterators.ArrayIterator<Dynamic>> {
		return ready.then(_ -> {
			final pool = StringTools.startsWith(qs[0].sql, "SELECT") ? readPool : writePool;
			return execute(pool, qs);
		});
	}

	public function exec(sql: String, ?params: Array<Dynamic>) {
		return execMany([{ sql: sql, params: params }]);
	}
}
#else
@:js.import("@sqlite.org/sqlite-wasm", "sqlite3Worker1Promiser")
extern class Worker1 {
	@:selfCall
	static var v2: ({ worker: () -> js.html.Worker }) -> Promise<Promiser>;
}

class SqliteDriver {
	private var sqlite: Promiser;
	private var dbId: String;
	private final ready: Promise<Bool>;
	private var setReady: (Bool)->Void;

	public function new(dbfile: String, migrate: (Array<String>->Promise<haxe.iterators.ArrayIterator<Dynamic>>)->Promise<Any>) {
		ready = new Promise((resolve, reject) -> setReady = resolve);
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
			return migrate((sql) -> this.execute(sql.map(q -> { sql: q, params: [] })));
		}).then(_ -> {
			setReady(true);
		});
	}

	private function execute(qs: Array<{ sql: String, ?params: Array<Dynamic> }>): Promise<haxe.iterators.ArrayIterator<Dynamic>> {
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

	public function execMany(qs: Array<{ sql: String, ?params: Array<Dynamic> }>): Promise<haxe.iterators.ArrayIterator<Dynamic>> {
		return ready.then(_ -> execute(qs));
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
