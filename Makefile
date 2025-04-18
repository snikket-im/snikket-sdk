HAXE_PATH=$$HOME/Software/haxe-4.3.1/hxnodejs/12,1,0/src

.PHONY: all test hx-build-dep cpp/output.dso npm/snikket-browser.js npm/snikket.js

all: npm libsnikket.so

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


npm/snikket-browser.js:
	haxe browserjs.hxml
	sed -i 's/import { snikket }/import { snikket as enums }/' npm/snikket-browser.d.ts
	sed -i 's/snikket\.UiState/enums.UiState/g' npm/snikket-browser.d.ts
	sed -i 's/snikket\.MessageStatus/enums.MessageStatus/g' npm/snikket-browser.d.ts
	sed -i 's/snikket\.MessageDirection/enums.MessageDirection/g' npm/snikket-browser.d.ts
	sed -i 's/snikket\.MessageType/enums.MessageType/g' npm/snikket-browser.d.ts
	sed -i 's/snikket\.UserState/enums.UserState/g' npm/snikket-browser.d.ts
	sed -i 's/snikket\.ChatMessageEvent/enums.ChatMessageEvent/g' npm/snikket-browser.d.ts
	sed -i 's/snikket\.ReactionUpdateKind/enums.ReactionUpdateKind/g' npm/snikket-browser.d.ts
	sed -i '1ivar exports = {};' npm/snikket-browser.js
	echo "export const snikket = exports.snikket;" >> npm/snikket-browser.js

npm/snikket.js:
	haxe nodejs.hxml
	sed -i 's/import { snikket }/import { snikket as enums }/' npm/snikket.d.ts
	sed -i 's/snikket\.UiState/enums.UiState/g' npm/snikket.d.ts
	sed -i 's/snikket\.MessageStatus/enums.MessageStatus/g' npm/snikket.d.ts
	sed -i 's/snikket\.MessageDirection/enums.MessageDirection/g' npm/snikket.d.ts
	sed -i 's/snikket\.MessageType/enums.MessageType/g' npm/snikket.d.ts
	sed -i 's/snikket\.UserState/enums.UserState/g' npm/snikket.d.ts
	sed -i 's/snikket\.ChatMessageEvent/enums.ChatMessageEvent/g' npm/snikket.d.ts
	sed -i 's/snikket\.ReactionUpdateKind/enums.ReactionUpdateKind/g' npm/snikket.d.ts
	sed -i '1iimport { createRequire } from "module";' npm/snikket.js
	sed -i '1iglobal.require = createRequire(import.meta.url);' npm/snikket.js
	sed -i '1ivar exports = {};' npm/snikket.js
	echo "export const snikket = exports.snikket;" >> npm/snikket.js

npm: npm/snikket-browser.js npm/snikket.js snikket/persistence/IDB.js snikket/persistence/MediaStoreCache.js snikket/persistence/sqlite-worker1.mjs
	cp snikket/persistence/IDB.js npm
	cp snikket/persistence/MediaStoreCache.js npm
	cp snikket/persistence/sqlite-worker1.mjs npm
	cd npm && npx tsc --esModuleInterop --lib esnext,dom --target esnext --preserveConstEnums -d index.ts
	sed -i '1iimport { snikket as enums } from "./snikket-enums.js";' npm/index.js

cpp/output.dso:
	haxe cpp.hxml

libsnikket.so: cpp/output.dso
	cp cpp/output.dso libsnikket.so

clean:
	rm -f npm/browser.js npm/index.js npm/snikket.js npm/snikket-enums.js
	rm -f npm/index.d.ts npm/snikket.d.ts npm/snikket-enums.d.ts npm/snikket-enums.ts
