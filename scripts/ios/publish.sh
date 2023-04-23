#!/bin/bash

OS=ios
TAG_COMMIT=$(git log -1 --pretty=format:"%H")

rm -rf flutter_libepiccash_bins
git clone https://git.cypherstack.com/stackwallet/flutter_libepiccash_bins
if [ -d flutter_libepiccash_bins ]; then
  cd flutter_libepiccash_bins
else
  echo "Failed to clone flutter_libepiccash_bins"
  exit 1
fi

TARGET_PATH=../build/rust/target
BIN=libepic_cash_wallet.a
HEADER=libepic_cash_wallet.h

for TARGET in aarch64-apple-ios x86_64-apple-ios
do
  if [ $(git tag -l "${TARGET}_${TAG_COMMIT}") ]; then
    echo "Tag ${TARGET}_${TAG_COMMIT} already exists!"
  else
    ARCH_PATH=$TARGET/release

    if [ -f "$TARGET_PATH/$ARCH_PATH/$BIN" ]; then
      git checkout $OS/$TARGET || git checkout -b $OS/$TARGET
      if [ ! -d $OS/$ARCH_PATH ]; then
        mkdir -p $OS/$ARCH_PATH
      fi
      cp -rf $TARGET_PATH/$ARCH_PATH/$BIN $OS/$ARCH_PATH/$BIN
      cp -rf $TARGET_PATH/../$HEADER $OS/$ARCH_PATH/$HEADER
      git add .
      git commit -m "$TARGET commit for $TAG_COMMIT"
      git push origin $OS/$TARGET
      git tag $TARGET"_$TAG_COMMIT"
      git push --tags
    else
      echo "$TARGET not found!"
    fi
  fi
done
