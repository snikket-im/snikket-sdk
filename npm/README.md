# Borogove

Borogove is a high-level headless chat SDK for building chat apps or chat experiences into other apps, backed by any [Snikket](https://snikket.org)-compatible server.

## Browser Workaround

There is a known bug in one of our JavaScript dependencies for browser builds, if xmpp.js is <= 0.14.0 then you may need something like this vite.config.js example

```js
resolve: {
	alias: {
		// https://github.com/xmppjs/xmpp.js/issues/1093
		"node:dns": "./src/dns-stub.js",
	},
},
```

And then the stub:

```js
export default {
	lookup: (x, y, cb) => cb(null, []),
	resolveSrv: (x, cb) => cb(null, []),
};
```

## Browser Sqlite

To use the sqlite persistence (rather than the default IndexedDB persistence) in a browser build, you will need the `@sqlite.org/sqlite-wasm` package and this additional import:

```js
import { borogove_persistence_Sqlite as borogoveSqlite } from "borogove/sqlite-wasm";
```

## Documentation

See https://borogove.dev/docs/js/
