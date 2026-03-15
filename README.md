# [Borogove](https://borogove.dev)

Working towards simplicity in developing Snikket-compatible apps.

    make hx-build-dep
    make

# JavaScript / TypeScript

`npm` subdirectory will contain installable package for browser or nodejs after build.

Also Typescript typings are generated which include documenation comments.

    npm install https://gitpkg-singpolyma.vercel.app/snikket-im/snikket-sdk/npm?compiled

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

# C

`libborogove.so` and `cpp/borogove.h`, the latter has documentation comments.

Alternately there is also `libborogove.batteriesincluded.so` which vendors some dependencies. Or `libborogove.a` which is a static library.

If you want to build on a system that does not have haxe:

    make cpp

The the `cpp` folder will contain C++ code and a Makefile with no haxe dependency.

[Alpine package](https://pkgs.alpinelinux.org/package/edge/community/x86/borogove-sdk)

# Swift

`libborogove.so` and `cpp/borogove.h` are wrapped by `cpp/Borogove.swift`

See also the [SwiftPM Package](https://borogove.dev/src/r/swiftpm/).

# Used By Apps Such As

* [Cheogram WWW](https://git.singpolyma.net/cheogram-www)
* [Cheogram CLI Dialler](https://git.singpolyma.net/ccd)
* [Cheogram iOS](https://git.singpolyma.net/cheogram-aapl)
* [Honeybee](https://sr.ht/~anjan/honeybee/)
