#!/bin/bash

LIB_ROOT=../..
ANDROID_LIBS_DIR=$LIB_ROOT/android/src/main/jniLibs

DL_DIR=bins

git clone "https://git.cypherstack.com/julian/flutter_libepiccash_bins" $DL_DIR

# TODO verify correct bins!!!!!!!!!!!!!!!!!!!!!!!

ARM64_BIN=arm64-v8a/libepic_cash_wallet.so

if [ -f "$DL_DIR/android/$ARM64_BIN" ]; then
  cp "$DL_DIR/android/$ARM64_BIN" "$ANDROID_LIBS_DIR/$ARM64_BIN"
else
  echo "$ARM64_BIN not found!"
fi

ARMEABI_V7A_BIN=armeabi-v7a/libepic_cash_wallet.so

if [ -f "$DL_DIR/android/$ARMEABI_V7A_BIN" ]; then
  cp "$DL_DIR/android/$ARMEABI_V7A_BIN" "$ANDROID_LIBS_DIR/$ARMEABI_V7A_BIN"
else
  echo "$ARMEABI_V7A_BIN not found!"
fi

X86_64_BIN=x86_64/libepic_cash_wallet.so

if [ -f "$DL_DIR/android/$X86_64_BIN" ]; then
  cp "$DL_DIR/android/$X86_64_BIN" "$ANDROID_LIBS_DIR/$X86_64_BIN"
else
  echo "$X86_64_BIN not found!"
fi
