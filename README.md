# Snikket SDK

Working towards simplicity in developing Snikket-compatible apps.

    haxelib install datetime haxe-strings hsluv tink_http sha thenshim
    make

# JavaScript

browser.js, though should also work on nodejs for the most part.
Also some typings are generated which include documenation comments.

# C

libsnikket.so and cpp/snikket.h, the latter has documentation comments

## Alpine Linux

## Build dependencies

Build haxelib and neko from this aports branch:

https://gitlab.alpinelinux.org/alpine/aports/-/merge_requests/69597

Install the required make dependencies:

``` sh
doas apk add opus-dev libdatachannel-dev libstrophe-dev libc++-dev musl-dev --virtual snikket-sdk-makedeps
```

Building the sdk requires a `xlocale.h` file which is the same as the `locale.h` on your computer (provided by the `musl-dev` package).


``` sh
doas ln -s /usr/include/locale.h /usr/include/xlocale.h
```

Install each of the haxe dependencies with each dependency on a new line:

``` sh
    haxelib install datetime
    haxelib install haxe-strings
    haxelib install ...
```

Build the c library using:

``` sh
make libsnikket.so
```

On completion, you can find `libsnikket.so` library at`./cpp/output.dso` and the `snikket.h` header file at `./cpp/snikket.h`.


# Swift

libsnikket.so and cpp/snikket.h are wrapped by cpp/Snikket.swift
