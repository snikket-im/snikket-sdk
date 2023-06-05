HAXE_PATH=$$HOME/Software/haxe-4.3.1/hxnodejs/12,1,0/src

.PHONY: all run-nodejs

all: test.node.js

test.node.js: xmpp/*.hx xmpp/queries/*.hx xmpp/streams/*.hx
	haxe -D nodejs -D no-deprecation-warnings -m Main --js "$@" -cp "$(HAXE_PATH)"

run-nodejs: test.node.js
	nodejs "$<"

