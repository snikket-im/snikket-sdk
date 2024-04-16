HAXE_PATH=$$HOME/Software/haxe-4.3.1/hxnodejs/12,1,0/src

.PHONY: all

all: browser.js libsnikket.so

browser.js:
	haxe browser.hxml
	echo "var exports = {};" > browser.js
	cat snikket/persistence/*.js >> browser.js
	echo "export const { snikket } = exports;" >> browser.js

cpp/output.dso:
	haxe cpp.hxml

libsnikket.so: cpp/output.dso
	cp cpp/output.dso libsnikket.so
