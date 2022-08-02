#!/bin/bash

mkdir build
cp -r ../../rust build/rust
cd build/rust
cargo build --target aarch64-unknown-linux-gnu --release --lib

mkdir -p target/x86_64-unknown-linux-gnu/release
cp target/aarch64-unknown-linux-gnu/release/libepic_cash_wallet.so target/x86_64-unknown-linux-gnu/release/
