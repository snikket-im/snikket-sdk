HAXE_PATH=$$HOME/Software/haxe-4.3.1/hxnodejs/12,1,0/src

.PHONY: all test cpp/output.dso npm/snikket-browser.js npm/snikket.js

all: npm libsnikket.so

test:
	haxe test.hxml

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
	sed -i 's/_Push.Push_Fields_/Push/g' npm/snikket-browser.d.ts
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
	sed -i 's/_Push.Push_Fields_/Push/g' npm/snikket.d.ts
	sed -i '1iimport { createRequire } from "module";' npm/snikket.js
	sed -i '1iglobal.require = createRequire(import.meta.url);' npm/snikket.js
	sed -i '1ivar exports = {};' npm/snikket.js
	echo "export const snikket = exports.snikket;" >> npm/snikket.js

npm: npm/snikket-browser.js npm/snikket.js snikket/persistence/browser.js
	cp snikket/persistence/browser.js npm
	cd npm && npx tsc --esModuleInterop --lib esnext,dom --target esnext --preserveConstEnums -d index.ts
	sed -i '1iimport { snikket as enums } from "./snikket-enums.js";' npm/index.js

cpp/output.dso:
	haxe cpp.hxml

libsnikket.so: cpp/output.dso
	cp cpp/output.dso libsnikket.so
