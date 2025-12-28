#!/usr/bin/env bash
set -e

# Prevent caching of build artifacts.
if [ -d "build" ]; then
    rm -rf build/
fi
# Prevent caching for example app.
if [ -d "../../example/macos/Pods" ]; then
    rm -rf ../../example/macos/Pods/
fi
# Prevent caching the library for Stack Wallet (if applicable).
if [ -f "../../../../macos/Pods" ]; then
    rm -rf ../../../../macos/Pods/
fi

mkdir build
echo ''$(git log -1 --pretty=format:"%H")' '$(date) >> build/git_commit_version.txt
VERSIONS_FILE=../../lib/git_versions.dart
EXAMPLE_VERSIONS_FILE=../../lib/git_versions_example.dart
if [ ! -f "$VERSIONS_FILE" ]; then
    cp $EXAMPLE_VERSIONS_FILE $VERSIONS_FILE
fi
COMMIT=$(git log -1 --pretty=format:"%H")
OSX="OSX"
sed -i '' '/\/\*${OS}_VERSION/c\'$'\n''/\*${OS}_VERSION\*\/ const ${OS}_VERSION = "'"$COMMIT"'";' "$VERSIONS_FILE"
cp -r ../../rust build/rust
cd build/rust

# building
cp target/epic_cash_wallet.h libepic_cash_wallet.h
cargo lipo --release --targets aarch64-apple-darwin

# Find and merge librandomx.a with libepic_cash_wallet.a
RANDOMX_LIB=$(find target/aarch64-apple-darwin/release/build -name "librandomx.a" | head -n 1)
if [ -f "$RANDOMX_LIB" ]; then
    echo "Found RandomX library at: $RANDOMX_LIB"
    # Merge the libraries using libtool
    libtool -static -o target/aarch64-apple-darwin/release/libepic_cash_wallet_combined.a \
        target/aarch64-apple-darwin/release/libepic_cash_wallet.a \
        "$RANDOMX_LIB"
    MAIN_LIB=target/aarch64-apple-darwin/release/libepic_cash_wallet_combined.a
else
    echo "Warning: librandomx.a not found, using libepic_cash_wallet.a only"
    MAIN_LIB=target/aarch64-apple-darwin/release/libepic_cash_wallet.a
fi

xcodebuild -create-xcframework \
  -library "$MAIN_LIB" \
  -headers libepic_cash_wallet.h \
  -output ../EpicWallet.xcframework

# moving files to the macos project
fwk=../../../../macos/framework/
rm -rf ${fwk}
mkdir ${fwk}
mv ../EpicWallet.xcframework ${fwk}