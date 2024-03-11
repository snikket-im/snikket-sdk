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
	cat snikket/persistence/*.js >> browser.js
	echo "export const { snikket } = exports;" >> browser.js
