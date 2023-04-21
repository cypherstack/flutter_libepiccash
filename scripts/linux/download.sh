#!/bin/bash

LIB_ROOT=../..
LINUX_LIBS_DIR=$LIB_ROOT/linux/bin

DL_DIR=bins

git clone "https://git.cypherstack.com/julian/flutter_libepiccash_bins" $DL_DIR

# TODO verify correct bins!!!!!!!!!!!!!!!!!!!!!!!

ARM_BIN=aarch64-unknown-linux-gnu/release/libepic_cash_wallet.so

if [ -f "$DL_DIR/linux/$ARM_BIN" ]; then
  cp "$DL_DIR/linux/$ARM_BIN" "$LINUX_LIBS_DIR/$ARM_BIN"
else
  echo "$ARM_BIN not found!"
fi

X86_64_BIN=x86_64-unknown-linux-gnu/release/libepic_cash_wallet.so

if [ -f "$DL_DIR/linux/$X86_64_BIN" ]; then
  cp "$DL_DIR/linux/$X86_64_BIN" "$LINUX_LIBS_DIR/$X86_64_BIN"
else
  echo "$X86_64_BIN not found!"
fi