HAXE_PATH=$$HOME/Software/haxe-4.3.1/hxnodejs/12,1,0/src

.PHONY: all test doc hx-build-dep cpp/libborogove.dso npm/borogove-browser.js npm/borogove.js cpp playwright ci

all: npm libborogove.batteriesincluded.so libborogove.so libborogove.a

test:
	haxe test.hxml

ci: test playwright
	mkdir .cache
	haxe testjs.hxml

hx-build-dep:
	haxelib --quiet git jsImport https://github.com/back2dos/jsImport
	haxelib --quiet install datetime
	haxelib --quiet install haxe-strings
	haxelib --quiet install hsluv
	haxelib --quiet install tink_http
	haxelib --quiet install uuidv7
	haxelib --quiet install fractional-indexing
	haxelib --quiet install thenshim
	haxelib --quiet install HtmlParser
	haxelib --quiet install hxnodejs
	haxelib --quiet git hxtsdgen https://github.com/singpolyma/hxtsdgen
	haxelib --quiet install utest
	haxelib --quiet git hxtsdgen https://github.com/singpolyma/hxtsdgen
	cd "$(shell haxelib libpath hxcpp)"/tools/hxcpp && haxe compile.hxml

npm/borogove-browser.js:
	haxe browserjs.hxml
	sed -i '/;var $$hx_exports = typeof exports != "undefined" ? exports : globalThis;/d' npm/borogove-browser.js
	sed -i '/\$$hx_exports.*|| {};/d' npm/borogove-browser.js
	sed -i 's/^$$hx_exports[^=]*=\(.*\);$$/export {\1 };/g' npm/borogove-browser.js
	sed -i 's/"\[Symbol.asyncIterator\]"() {/[Symbol.asyncIterator]() {/g' npm/borogove-browser.js
	cd npm && npx cjstoesm borogove-browser.js
	sed -i 's/import crypto from "crypto";//g' npm/borogove-browser.js
	awk -f optional-sqlite.awk npm/borogove-browser.js
	mv npm/browser-no-sqlite.js npm/borogove-browser.js
	awk -f optional-sqlite-types.awk npm/borogove-browser.d.ts
	mv npm/no-sqlite.d.ts npm/borogove-browser.d.ts
	echo "export class borogove_Presence {}" >> npm/borogove-browser.d.ts

npm/borogove.js:
	haxe nodejs.hxml
	sed -i '/;var $$hx_exports = typeof exports != "undefined" ? exports : globalThis;/d' npm/borogove.js
	sed -i '/\$$hx_exports.*|| {};/d' npm/borogove.js
	sed -i 's/^$$hx_exports[^=]*=\(.*\);$$/export {\1 };/g' npm/borogove.js
	sed -i 's/"\[Symbol.asyncIterator\]"() {/[Symbol.asyncIterator]() {/g' npm/borogove.js
	cd npm && npx cjstoesm borogove.js
	echo "export class borogove_Presence {}" >> npm/borogove.d.ts

npm: npm/borogove-browser.js npm/borogove.js borogove/persistence/IDB.js borogove/persistence/MediaStoreCache.js borogove/persistence/sqlite-worker1.mjs
	cp borogove/persistence/IDB.js npm
	cp borogove/persistence/MediaStoreCache.js npm
	cp borogove/persistence/sqlite-worker1.mjs npm
	-cd npm && npx tsc --esModuleInterop --lib esnext,dom --target esnext --preserveConstEnums --allowJs --checkJs -d index.ts > /dev/null
	cd npm && npx tsc --esModuleInterop --lib esnext,dom --target esnext --preserveConstEnums --allowJs --checkJs -d index.ts

playwright/.cache/borogove.js: npm
	esbuild npm/index.js --bundle --format=esm "--alias:node:dns=@xmpp/resolve" "--footer:js=export { borogove_JID as JID, borogove_Stanza as Stanza, borogove_ReactionUpdate as ReactionUpdate }" --outfile=$@

playwright/.cache/sqlite-wasm.js: npm
	esbuild npm/sqlite-wasm.js --bundle --format=esm "--alias:node:dns=@xmpp/resolve" --outfile=$@
	sed -i 's/new URL("sqlite-worker1.mjs", import.meta.url)/window.sqliteWorker1Url/g' $@

playwright/.cache/sqlite-worker1.js: npm
	esbuild npm/sqlite-worker1.mjs --bundle --format=esm --outfile=$@.mjs
	sed -i '1iimport importedWasm from "@sqlite.org\\/sqlite-wasm/sqlite3.wasm";' $@.mjs
	sed -i 's/new URL("sqlite3.wasm", import.meta.url).href/importedWasm/' $@.mjs
	esbuild $@.mjs --bundle --format=esm --loader:.wasm=dataurl --outfile=$@
	$(RM) $@.mjs

playwright: playwright/.cache/borogove.js playwright/.cache/sqlite-wasm.js
	npx playwright test

cpp/libborogove.dso:
	haxe cpp.hxml
	$(RM) cpp/libborogove.dso.hash

cpp:
	haxe -D no-compilation cpp.hxml
	$(RM) -r cpp/obj
	$(RM) cpp/*.dso
	$(RM) cpp/src/__main__.cpp
	$(RM) cpp/src/__files__.cpp
	cp -p "$(shell haxelib libpath hxcpp)"/include/*.h cpp/include/
	cp -pr "$(shell haxelib libpath hxcpp)"/include/hx cpp/include/
	cp -pr "$(shell haxelib libpath hxcpp)"/include/cpp cpp/include/
	mkdir -p cpp/src/hx/libs/ssl
	cp -p cpp/alt/SSL-mbedtls3.cpp cpp/src/hx/libs/ssl/SSL.cpp
	cp -pr "$(shell haxelib libpath hxcpp)"/src/hx/libs/std cpp/src/hx/libs/
	cp -pr "$(shell haxelib libpath hxcpp)"/src/hx/libs/regexp cpp/src/hx/libs/
	cp -pr "$(shell haxelib libpath hxcpp)"/src/hx/libs/sqlite cpp/src/hx/libs/
	cp -pr "$(shell haxelib libpath hxcpp)"/src/hx/gc cpp/src/hx/
	cp -p "$(shell haxelib libpath hxcpp)"/src/hx/StdLibs.cpp cpp/src/hx/
	cp -p "$(shell haxelib libpath hxcpp)"/src/hx/Lib.cpp cpp/src/hx/
	cp -p "$(shell haxelib libpath hxcpp)"/src/hx/Hash.h cpp/src/hx/
	cp -p "$(shell haxelib libpath hxcpp)"/src/hx/Hash.cpp cpp/src/hx/
	cp -p "$(shell haxelib libpath hxcpp)"/src/hx/Date.cpp cpp/src/hx/
	cp -p "$(shell haxelib libpath hxcpp)"/src/hx/Thread.cpp cpp/src/hx/
	cp -p "$(shell haxelib libpath hxcpp)"/src/hx/CFFI.cpp cpp/src/hx/
	cp -p "$(shell haxelib libpath hxcpp)"/src/hx/Unicase.h cpp/src/hx/
	cp -p "$(shell haxelib libpath hxcpp)"/src/hx/Debug.cpp cpp/src/hx/
	cp -p "$(shell haxelib libpath hxcpp)"/src/hx/Anon.cpp cpp/src/hx/
	cp -p "$(shell haxelib libpath hxcpp)"/src/hx/Class.cpp cpp/src/hx/
	cp -p "$(shell haxelib libpath hxcpp)"/src/hx/Object.cpp cpp/src/hx/
	cp -p "$(shell haxelib libpath hxcpp)"/src/hx/Boot.cpp cpp/src/hx/
	cp -p "$(shell haxelib libpath hxcpp)"/src/hx/NoFiles.cpp cpp/src/hx/
	cp -p "$(shell haxelib libpath hxcpp)"/src/String.cpp cpp/src/
	cp -p "$(shell haxelib libpath hxcpp)"/src/Enum.cpp cpp/src/
	cp -p "$(shell haxelib libpath hxcpp)"/src/Array.cpp cpp/src/
	cp -p "$(shell haxelib libpath hxcpp)"/src/Dynamic.cpp cpp/src/
	cp -p "$(shell haxelib libpath hxcpp)"/src/Math.cpp cpp/src/
	cd cpp && ./configure.simple

libborogove.batteriesincluded.so: cpp/libborogove.dso
	mv cpp/libborogove.dso libborogove.batteriesincluded.so

cpp/libborogove.so: cpp
	$(MAKE) -C cpp libborogove.so

cpp/libborogove.a: cpp
	$(MAKE) -C cpp libborogove.a

libborogove.so: cpp/libborogove.so
	mv cpp/libborogove.so libborogove.so

libborogove.a: cpp/libborogove.a
	mv cpp/libborogove.a libborogove.a

doc:
	npx @microsoft/api-extractor run -c npm/api-extractor.json || true
	npx @microsoft/api-documenter markdown -i tmp -o docs/js/
	rm -r tmp
	find docs/js/ -name '*.md' -exec sed -i 's/<\([[:alpha:]][[:alpha:]]*\)/<\1 markdown="1"/g' \{\} \;
	git checkout docs/js/index.md
	mkdocs build
	haxe haxedoc.hxml
	haxelib run dox --toplevel-package borogove -i haxedoc.xml -o site/haxe/

clean:
	$(RM) npm/*.js npm/*.mjs npm/*.d.ts npm/*.map npm/borogove-enums.ts npm/borogove-browser-enums.ts
	$(RM) -r cpp/src cpp/include cpp/obj cpp/*.h cpp/*.dso.hash cpp/Build.xml cpp/Options.txt cpp/Borogove.swift libborogove.so
