#!/bin/bash

mkdir build
cp -r ../../rust build/rust
cd build/rust
cargo build --target x86_64-unknown-linux-gnu --release --lib
