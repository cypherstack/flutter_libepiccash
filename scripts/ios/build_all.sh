#!/usr/bin/env bash
mkdir build
echo ''$(git log -1 --pretty=format:"%H")' '$(date) >> build/git_commit_version.txt
VERSIONS_FILE=../../lib/git_versions.dart
EXAMPLE_VERSIONS_FILE=../../lib/git_versions_example.dart
if [ ! -f "$VERSIONS_FILE" ]; then
    cp $EXAMPLE_VERSIONS_FILE $VERSIONS_FILE
fi
COMMIT=$(git log -1 --pretty=format:"%H")
OS="IOS"
sed -i '' "/\/\*${OS}_VERSION/c\\/\*${OS}_VERSION\*\/ const ${OS}_VERSION = \"$COMMIT\";" $VERSIONS_FILE
cp -r ../../rust build/rust
cd build/rust

rustup target add aarch64-apple-ios x86_64-apple-ios

# building
cbindgen src/lib.rs -l c > libepic_cash_wallet.h
cargo lipo --release

# moving files to the ios project
inc=../../../../ios/include
libs=../../../../ios/libs

rm -rf ${inc} ${libs}

mkdir ${inc}
mkdir ${libs}

cp libepic_cash_wallet.h ${inc}
cp target/aarch64-apple-ios/release/libepic_cash_wallet.a ${libs}