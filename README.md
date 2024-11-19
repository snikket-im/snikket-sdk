# Snikket SDK

https://github.com/snikket-im/snikket-sdk

Working towards simplicity in developing Snikket-compatible apps.

  haxelib setup ~/haxe
  haxelib --quiet git jsImport https://github.com/back2dos/jsImport
  haxelib --quiet install datetime
  haxelib --quiet install haxe-strings
  haxelib --quiet install hsluv
  haxelib --quiet install tink_http
  haxelib --quiet install sha
  haxelib --quiet install thenshim
  haxelib --quiet install HtmlParser
  haxelib --quiet install hxnodejs
  haxelib --quiet git hxtsdgen https://github.com/singpolyma/hxtsdgen
  haxelib --quiet install utest
  haxelib --quiet git hxcpp https://github.com/HaxeFoundation/hxcpp
  cd ~/haxe/hxcpp/git/tools/hxcpp
    haxe compile.hxml
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
