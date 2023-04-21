#!/bin/bash

if [ -z "$1" ]; then
    echo "Failed to copy lib bins. Missing target root dir path"
    exit 1
fi


TARGET_PATH=build/rust/target

ARM_BIN=aarch64-unknown-linux-gnu/release/libepic_cash_wallet.so

if [ -f "$TARGET_PATH/$ARM_BIN" ]; then
  cp "$TARGET_PATH/$ARM_BIN" "$1"/linux/bin/"$ARM_BIN"
else
  echo "$ARM_BIN not found!"
fi


X86_64_BIN=x86_64-unknown-linux-gnu/release/libepic_cash_wallet.so

if [ -f "$TARGET_PATH/$X86_64_BIN" ]; then
  cp "$TARGET_PATH/$X86_64_BIN" "$1"/linux/bin/"$X86_64_BIN"
else
  echo "$X86_64_BIN not found!"
fi