package snikket.persistence;

import haxe.io.Bytes;
import thenshim.Promise;
import sys.db.Connection;

// TODO: consider doing background threads for operations
class SqliteDriver {
	final db: Connection;

	public function new(dbfile: String) {
		db = sys.db.Sqlite.open(dbfile);
		db.request("PRAGMA journal_mode=WAL");
	}

	public function exec(sql: haxe.extern.EitherType<String, Array<String>>, ?params: Array<Dynamic>) {
		var result = null;
		final qs = if (Std.isOfType(sql, String)) {
			[sql];
		} else {
			cast (sql, Array<Dynamic>);
		}
		try {
			for (q in qs) {
				if (result == null) {
					final prepared = prepare(q, params ?? []);
					result = db.request(prepared);
				} else {
					db.request(q);
				}
			}
			return Promise.resolve(result);
		} catch (e) {
			return Promise.reject(e);
		}
	}

	private function prepare(sql:String, params: Array<Dynamic>): String {
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
