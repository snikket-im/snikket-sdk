BEGIN {
	skipping = 0
	extra = 0
}

/^import \{ sqlite3Worker1Promiser as borogove_persistence_Worker1 \} from "@sqlite\.org\/sqlite-wasm";/ {
	print > "npm/sqlite-wasm.js"
	print "var $global = globalThis;" >> "npm/sqlite-wasm.js"
	next
}

/^borogove_persistence_Sqlite.__meta__ =/ {
	print >> "npm/sqlite-wasm.js"
	next
}

/^class borogove_persistence_Sqlite {/ {
	skipping = 1
}

/borogove_persistence_SqliteDriver.__name__ = "borogove\.persistence\.SqliteDriver";/ {
	if (skipping) extra = 6
}

/^export \{ borogove_persistence_Sqlite \};/ {
	print >> "npm/sqlite-wasm.js"
	next
}

skipping {
	print >> "npm/sqlite-wasm.js"

	if (extra > 0) {
		extra--
		if (extra == 0) skipping = 0
	}
	next
}

{
	print > "npm/browser-no-sqlite.js"
}
