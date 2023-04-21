#!/bin/bash

if [ -z "$1" ]; then
    echo "Failed to copy lib bins. Missing target root dir path"
    exit 1
fi

TARGET_PATH=../../android/src/main/jniLibs

ARM64_BIN=arm64-v8a/libepic_cash_wallet.so

if [ -f "$TARGET_PATH/$ARM64_BIN" ]; then
  cp "$TARGET_PATH/$ARM64_BIN" "$1"/android/src/main/jniLibs/"$ARM64_BIN"
else
  echo "$ARM64_BIN not found!"
fi

ARMEABI_V7A_BIN=armeabi-v7a/libepic_cash_wallet.so

if [ -f "$TARGET_PATH/$ARMEABI_V7A_BIN" ]; then
  cp "$TARGET_PATH/$ARMEABI_V7A_BIN" "$1"/android/src/main/jniLibs/"$ARMEABI_V7A_BIN"
else
  echo "$ARMEABI_V7A_BIN not found!"
fi

X86_64_BIN=x86_64/libepic_cash_wallet.so

if [ -f "$TARGET_PATH/$X86_64_BIN" ]; then
  cp "$TARGET_PATH/$X86_64_BIN" "$1"/android/src/main/jniLibs/"$X86_64_BIN"
else
  echo "$X86_64_BIN not found!"
fi
