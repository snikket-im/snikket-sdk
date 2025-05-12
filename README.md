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

<details>
<summary><h2>Alpine Linux</h2></summary>

Build haxelib and neko from this aports branch:

https://gitlab.alpinelinux.org/alpine/aports/-/merge_requests/69597

Install the required make dependencies:

    doas apk add opus-dev libdatachannel-dev libstrophe-dev libc++-dev musl-dev --virtual snikket-sdk-makedeps

Building the sdk requires a `xlocale.h` file which is the same as the `locale.h` on your computer (provided by the `musl-dev` package).

    doas ln -s /usr/include/locale.h /usr/include/xlocale.h

Install the haxe dependencies and run make as above.
</details>

# Swift

libsnikket.so and cpp/snikket.h are wrapped by cpp/Snikket.swift
