#!/usr/bin/env bash
mkdir build
printf $(git log -1 --pretty=format:"%h %ad") >> build/git_commit_version.txt
cp -r ../../rust build/rust
cd build/rust

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