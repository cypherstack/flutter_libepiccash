#!/bin/bash

. ./install_ndk.sh
. ./build_openssl.sh
. ./config.sh

# shellcheck disable=SC2164
cd "${WORKDIR}"
echo "${WORKDIR}"

rm -r ../../../android/src/main/jniLibs/
echo ''$(git log -1 --pretty=format:"%H")' '$(date) >> git_commit_version.txt
VERSIONS_FILE=../../../lib/git_versions.dart
EXAMPLE_VERSIONS_FILE=../../../lib/git_versions_example.dart
if [ ! -f "$VERSIONS_FILE" ]; then
    cp $EXAMPLE_VERSIONS_FILE $VERSIONS_FILE
fi
COMMIT=$(git log -1 --pretty=format:"%H")
OS="ANDROID"
sed -i "/\/\*${OS}_VERSION/c\\/\*${OS}_VERSION\*\/ const ${OS}_VERSION = \"$COMMIT\";" $VERSIONS_FILE

cp -r ../../../rust rust
# shellcheck disable=SC2164
cd rust
rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android

# TODO Investigate why x86 does not build
cargo ndk -t armeabi-v7a -t arm64-v8a -t x86_64 -o ../../../../android/src/main/jniLibs build --release
