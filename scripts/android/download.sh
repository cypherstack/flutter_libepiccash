#!/bin/bash

LIB_ROOT=../..
OS=android
ANDROID_LIBS_DIR=$LIB_ROOT/android/src/main/jniLibs

TAG_COMMIT=$(git log -1 --pretty=format:"%H")

rm -rf flutter_libepiccash_bins
git clone https://git.cypherstack.com/stackwallet/flutter_libepiccash_bins
if [ -d flutter_libepiccash_bins ]; then
  cd flutter_libepiccash_bins
else
  echo "Failed to clone flutter_libepiccash_bins"
  exit 1
fi

BIN=libepic_cash_wallet.so

for TARGET in arm64-v8a armeabi-v7a x86_64
do
  ARCH_PATH=$TARGET
  if [ $(git tag -l "${OS}_${TARGET}_${TAG_COMMIT}") ]; then
      git checkout "${OS}_${TARGET}_${TAG_COMMIT}" || git checkout $OS/$TARGET
      if [ -f "$OS/$ARCH_PATH/$BIN" ]; then
        mkdir -p ../$ANDROID_LIBS_DIR/$ARCH_PATH
        # TODO verify bin checksum hashes
        cp -rf "$OS/$ARCH_PATH/$BIN" "../$ANDROID_LIBS_DIR/$ARCH_PATH/$BIN"
      else
        echo "$TARGET not found at $OS/$ARCH_PATH/$BIN!"
      fi
  else
      echo "No precompiled bins for $TARGET found!"
  fi
done
