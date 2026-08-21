#!/bin/bash

set -e

LIB_ROOT=../..
REPO="cypherstack/flutter_libepiccash"
BASE_URL="https://github.com/${REPO}/releases/download"

TAG=$(git -C "$LIB_ROOT" describe --tags --exact-match HEAD 2>/dev/null) || {
    echo "Error: flutter_libepiccash is not at a tagged commit."
    echo "Pin the submodule to a release tag to use download mode."
    echo "Current commit: $(git -C "$LIB_ROOT" rev-parse HEAD)"
    exit 1
}

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

curl -fSL "${BASE_URL}/${TAG}/checksums.txt" -o "$TMPDIR/checksums.txt"

download_and_verify() {
    local asset="$1"
    curl -fSL "${BASE_URL}/${TAG}/${asset}" -o "$TMPDIR/${asset}"
    grep "^[0-9a-f]*  ${asset}$" "$TMPDIR/checksums.txt" | (cd "$TMPDIR" && shasum -a 256 -c)
}

download_and_verify "libepic_cash_wallet-ios-aarch64.a"
download_and_verify "libepic_cash_wallet.h"

mkdir -p "$LIB_ROOT/ios/libs" "$LIB_ROOT/ios/include"
cp "$TMPDIR/libepic_cash_wallet-ios-aarch64.a" "$LIB_ROOT/ios/libs/libepic_cash_wallet.a"
cp "$TMPDIR/libepic_cash_wallet.h"             "$LIB_ROOT/ios/include/libepic_cash_wallet.h"

# Release artifacts are device-only; wrap the device slice in an XCFramework
# so the podspec's vendored_frameworks entry resolves. Simulator consumers
# must additionally run scripts/ios/build_sim.sh.
PLUGIN_ROOT="$(cd "$LIB_ROOT" && pwd)"
rm -rf "$PLUGIN_ROOT/ios/libs/epiccash.xcframework"
xcodebuild -create-xcframework \
    -library "$PLUGIN_ROOT/ios/libs/libepic_cash_wallet.a" \
    -headers "$PLUGIN_ROOT/ios/include" \
    -output "$PLUGIN_ROOT/ios/libs/epiccash.xcframework"
