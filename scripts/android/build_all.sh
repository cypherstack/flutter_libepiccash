#!/bin/bash


. ./config.sh
cp -r ../../rust build/rust
cd build/rust
rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android

# TODO Investigate why x86 does not build
cargo ndk -t armeabi-v7a -t arm64-v8a -t x86_64 -o ../../../../android/src/main/jniLibs build
