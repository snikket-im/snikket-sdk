HAXE_PATH=$$HOME/Software/haxe-4.3.1/hxnodejs/12,1,0/src

.PHONY: all test cpp/output.dso npm/snikket.js

all: npm libsnikket.so

test:
	haxe test.hxml

npm/snikket.js:
	haxe js.hxml
	sed -i 's/import { snikket }/import { snikket as enums }/' npm/snikket.d.ts
	sed -i 's/snikket\.UiState/enums.UiState/g' npm/snikket.d.ts
	sed -i 's/snikket\.MessageStatus/enums.MessageStatus/g' npm/snikket.d.ts
	sed -i 's/snikket\.MessageDirection/enums.MessageDirection/g' npm/snikket.d.ts
	sed -i '1ivar exports = {};' npm/snikket.js
	echo "export const snikket = exports.snikket;" >> npm/snikket.js

npm: npm/snikket.js snikket/persistence/browser.js
	cp snikket/persistence/browser.js npm
	cd npm && npx tsc --esModuleInterop --lib esnext,dom --target esnext --preserveConstEnums -d index.ts
	sed -i '1iimport { snikket as enums } from "./snikket-enums";' npm/index.js

cpp/output.dso:
	haxe cpp.hxml

libsnikket.so: cpp/output.dso
	cp cpp/output.dso libsnikket.so
