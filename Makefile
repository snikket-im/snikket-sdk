HAXE_PATH=$$HOME/Software/haxe-4.3.1/hxnodejs/12,1,0/src

.PHONY: all test doc hx-build-dep cpp/output.dso npm/borogove-browser.js npm/borogove.js

all: npm libborogove.so

test:
	haxe test.hxml

hx-build-dep:
	haxelib --quiet git jsImport https://github.com/back2dos/jsImport
	haxelib --quiet install datetime
	haxelib --quiet install haxe-strings
	haxelib --quiet install hsluv
	haxelib --quiet install tink_http
	haxelib --quiet install sha
	haxelib --quiet install thenshim
	haxelib --quiet install HtmlParser
	haxelib --quiet install hxnodejs
	haxelib --quiet git hxtsdgen https://github.com/singpolyma/hxtsdgen
	haxelib --quiet install utest
	haxelib --quiet git hxcpp https://github.com/HaxeFoundation/hxcpp

npm/borogove-browser.js:
	haxe browserjs.hxml
	sed -i '/;var $$hx_exports = typeof exports != "undefined" ? exports : globalThis;/{N;N;N;d;}' npm/borogove-browser.js
	sed -i 's/^$$hx_exports[^=]*=\(.*\);$$/export {\1 };/g' npm/borogove-browser.js

npm/borogove.js:
	haxe nodejs.hxml
	sed -i '/;var $$hx_exports = typeof exports != "undefined" ? exports : globalThis;/{N;N;N;d;}' npm/borogove.js
	sed -i 's/^$$hx_exports[^=]*=\(.*\);$$/export {\1 };/g' npm/borogove.js
	cd npm && npx cjstoesm borogove.js

npm: npm/borogove-browser.js npm/borogove.js borogove/persistence/IDB.js borogove/persistence/MediaStoreCache.js borogove/persistence/sqlite-worker1.mjs
	cp borogove/persistence/IDB.js npm
	cp borogove/persistence/MediaStoreCache.js npm
	cp borogove/persistence/sqlite-worker1.mjs npm
	-cd npm && npx tsc --esModuleInterop --lib esnext,dom --target esnext --preserveConstEnums --allowJs --checkJs -d index.ts > /dev/null
	cd npm && npx tsc --esModuleInterop --lib esnext,dom --target esnext --preserveConstEnums --allowJs --checkJs -d index.ts

cpp/output.dso:
	haxe cpp.hxml

libborogove.so: cpp/output.dso
	mv cpp/output.dso libborogove.so

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
	rm -f npm/browser.js npm/index.js npm/borogove.js npm/borogove-enums.js
	rm -f npm/index.d.ts npm/borogove.d.ts npm/borogove-enums.d.ts npm/borogove-enums.ts
