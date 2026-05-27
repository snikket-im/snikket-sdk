# [Borogove](https://borogove.dev)

Borogove is a high-level headless chat SDK for building chat apps or chat experiences into other apps, backed by any [Snikket](https://snikket.org)-compatible server.

## Building Everything

    make hx-build-dep
    make

## Running Tests

    make test

or, for a more comprehensive and slower set of tests:

    make ci

## JavaScript / TypeScript

`npm` subdirectory will contain installable package for browser or nodejs after build, or simply:

    npm i borogove

Typescript typings are generated which include documenation comments.

## C

`libborogove.so` and `cpp/borogove.h`, the latter has documentation comments.

Alternately there is also `libborogove.batteriesincluded.so` which vendors some dependencies. Or `libborogove.a` which is a static library.

If you want to build on a system that does not have Haxe:

    make cpp

The the `cpp` folder will contain C++ code and a Makefile with no haxe dependency.

## Swift

`libborogove.so` and `cpp/borogove.h` are wrapped by `cpp/Borogove.swift`

See also the [SwiftPM Package](https://borogove.dev/src/r/swiftpm/).

## Documentation

https://borogove.dev/docs/
