HAXE_PATH=$$HOME/Software/haxe-4.3.1/hxnodejs/12,1,0/src

.PHONY: all run-nodejs

all: test.node.js

test.node.js: snikket/*.hx snikket/queries/*.hx snikket/streams/*.hx
	haxe -D nodejs -D no-deprecation-warnings -m Main --js "$@" -cp "$(HAXE_PATH)"

run-nodejs: test.node.js
	nodejs "$<"

browser.js:
	haxe browser.hxml
	echo "var exports = {};" > browser.js
	sed -e 's/hxEnums\["snikket.EventResult"\] = {/hxEnums["snikket.EventResult"] = $$hx_exports.snikket.EventResult = {/' < browser.haxe.js | sed -e 's/hxEnums\["snikket.MessageDirection"\] = {/hxEnums["snikket.MessageDirection"] = $$hx_exports.snikket.MessageDirection = {/' | sed -e 's/hxEnums\["snikket.UiState"\] = {/hxEnums["snikket.UiState"] = $$hx_exports.snikket.UiState = {/' | sed -e 's/hxEnums\["snikket.MessageStatus"\] = {/hxEnums["snikket.MessageStatus"] = $$hx_exports.snikket.MessageStatus = {/' >> browser.js
	cat snikket/persistence/*.js >> browser.js
	echo "export const { snikket } = exports;" >> browser.js
