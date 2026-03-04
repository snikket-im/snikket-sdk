BEGIN {
	skipping = 0
	extra = 0
}

/^import \{ sqlite3Worker1Promiser as borogove_persistence_Worker1 \} from "@sqlite\.org\/sqlite-wasm";/ {
	print > "npm/sqlite-wasm.js"
	print "import * as borogove from \"./borogove-browser.js\"" >> "npm/sqlite-wasm.js"
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
	line = $0
	gsub(/borogove_persistence_Sqlite/, "__TEMP_KEEP__", line)
	gsub(/borogove_persistence_Worker1/, "__TEMP_KEEP2__", line)
	gsub(/borogove_/, "borogove.borogove_", line)
	gsub("__TEMP_KEEP__", "borogove_persistence_Sqlite", line)
	gsub("__TEMP_KEEP2__", "borogove_persistence_Worker1", line)
	print line >> "npm/sqlite-wasm.js"

	if (extra > 0) {
		extra--
		if (extra == 0) skipping = 0
	}
	next
}

{
	print > "npm/browser-no-sqlite.js"
}

END {
	print "export { borogove_Map }" >> "npm/browser-no-sqlite.js"
}
