/^export class borogove_persistence_Sqlite implements borogove_persistence_KeyValueStore, borogove_Persistence[[:space:]]*\{/ {
    inside = 1
    brace_count = 0

    n = gsub(/\{/, "{")
    brace_count += n
    n = gsub(/\}/, "}")
    brace_count -= n

    print >> "npm/sqlite-wasm.d.ts"
    next
}

inside {
    print >> "npm/sqlite-wasm.d.ts"

    n = gsub(/\{/, "{")
    brace_count += n
    n = gsub(/\}/, "}")
    brace_count -= n

    if (brace_count == 0) inside = 0

    next
}

{ print > "npm/no-sqlite.d.ts" }
