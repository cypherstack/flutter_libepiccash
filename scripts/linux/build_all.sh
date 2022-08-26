#!/bin/bash

mkdir build
printf $(git log -1 --pretty=format:"%h %ad") >> build/git_commit_version.txt
cp -r ../../rust build/rust
cd build/rust
if [ "$IS_ARM" = true ]  ; then
    echo "Building arm version"
    cargo build --target aarch64-unknown-linux-gnu --release --lib

    mkdir -p target/x86_64-unknown-linux-gnu/release
    cp target/aarch64-unknown-linux-gnu/release/libepic_cash_wallet.so target/x86_64-unknown-linux-gnu/release/
else
    echo "Building x86_64 version"
    cargo build --target x86_64-unknown-linux-gnu --release --lib
fi
