# [Borogove](https://borogove.dev)

Working towards simplicity in developing Snikket-compatible apps.

    haxelib git jsImport https://github.com/back2dos/jsImport
    haxelib install datetime
    haxelib install haxe-strings
    haxelib install hsluv
    haxelib install tink_http
    haxelib install sha
    haxelib install thenshim
    haxelib install HtmlParser
    haxelib install hxnodejs
    haxelib git hxtsdgen https://github.com/singpolyma/hxtsdgen
    haxelib install utest
    haxelib git hxcpp https://github.com/singpolyma/hxcpp update-sqlite
    cd ~/haxe/hxcpp/git/tools/hxcpp
    haxe compile.hxml
    cd -
    make

# JavaScript / TypeScript

`npm` subdirectory will contain installable package for browser or nodejs after build.

Also Typescript typings are generated which include documenation comments.

    npm install https://gitpkg-singpolyma.vercel.app/snikket-im/snikket-sdk/npm?compiled

# C

`libborogove.so` and `cpp/borogove.h`, the latter has documentation comments

## Alpine Linux

See [borogove-sdk build recipe](https://pkgs.alpinelinux.org/package/edge/testing/x86_64/borogove-sdk)

# Swift

`libborogove.so` and `cpp/borogove.h` are wrapped by `cpp/Borogove.swift`

See also the [SwiftPM Package](https://borogove.dev/src/r/swiftpm/).

# Used By Apps Such As

* [Cheogram WWW](https://git.singpolyma.net/cheogram-www)
* [Cheogram CLI Dialler](https://git.singpolyma.net/ccd)
* [Cheogram iOS](https://git.singpolyma.net/cheogram-aapl)
* [Honeybee](https://sr.ht/~anjan/honeybee/)
