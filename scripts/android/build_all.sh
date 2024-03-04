#!/bin/bash

. ./config.sh
rm -r ../../android/src/main/jniLibs/
echo ''$(git log -1 --pretty=format:"%H")' '$(date) >> build/git_commit_version.txt
VERSIONS_FILE=../../lib/git_versions.dart
EXAMPLE_VERSIONS_FILE=../../lib/git_versions_example.dart
if [ ! -f "$VERSIONS_FILE" ]; then
    cp $EXAMPLE_VERSIONS_FILE $VERSIONS_FILE
fi
COMMIT=$(git log -1 --pretty=format:"%H")
OS="ANDROID"
sed -i "/\/\*${OS}_VERSION/c\\/\*${OS}_VERSION\*\/ const ${OS}_VERSION = \"$COMMIT\";" $VERSIONS_FILE
cp -r ../../rust build/rust
cd build/rust
rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android

# Hacky fix which we will probably have to revisit and fix later.
export ANDROID_NDK_ROOT=~/Android/Sdk/ndk/21.1.6352462
export ANDROID_NDK_HOME=~/Android/Sdk/ndk/21.1.6352462
export PATH=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin:$ANDROID_NDK_ROOT/toolchains/arm-linux-androideabi-4.9/prebuilt/linux-x86_64/bin:$PATH
    ./Configure android-arm64 -D__ANDROID_API__=21

# TODO Investigate why x86 does not build
cargo ndk -t armeabi-v7a -t arm64-v8a -t x86_64 -o ../../../../android/src/main/jniLibs build --release
