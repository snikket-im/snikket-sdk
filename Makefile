HAXE_PATH=$$HOME/Software/haxe-4.3.1/hxnodejs/12,1,0/src

.PHONY: all test cpp/output.dso browser.js

all: browser.js libsnikket.so

test:
	haxe test.hxml

browser.js:
	haxe browser.hxml
	echo "var exports = {};" > browser.js
	cat snikket/persistence/*.js >> browser.js
	echo "export const { snikket } = exports;" >> browser.js

cpp/output.dso:
	haxe cpp.hxml

libsnikket.so: cpp/output.dso
	cp cpp/output.dso libsnikket.so
