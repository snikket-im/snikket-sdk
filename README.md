# Snikket SDK

https://github.com/snikket-im/snikket-sdk

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

# JavaScript

npm subdirectory will contain installable package for browser or nodejs after build.
Also some typings are generated which include documenation comments.

    npm install https://gitpkg-singpolyma.vercel.app/snikket-im/snikket-sdk/npm?compiled

# C

libsnikket.so and cpp/snikket.h, the latter has documentation comments

## Alpine Linux

See snikket-sdk build recipe: https://pkgs.alpinelinux.org/package/edge/testing/x86_64/snikket-sdk

# Swift

libsnikket.so and cpp/snikket.h are wrapped by cpp/Snikket.swift
