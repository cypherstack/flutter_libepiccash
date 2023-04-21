#!/bin/bash

OS=linux
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
BIN=libepic_cash_wallet.so

for TARGET in aarch64-unknown-linux-gnu x86_64-unknown-linux-gnu
do
  ARCH_PATH=$TARGET/release

  if [ -f "$TARGET_PATH/$ARCH_PATH/$BIN" ]; then
    git checkout $OS/$TARGET || git checkout -b $OS/$TARGET
    if [ ! -d $OS/$ARCH_PATH ]; then
      mkdir -p $OS/$ARCH_PATH
    fi
    cp -rf $TARGET_PATH/$ARCH_PATH/$BIN $OS/$ARCH_PATH/$BIN
    git add .
    git commit -m "$TAG_COMMIT"
    git push origin $OS/$TARGET
    git tag $TARGET"_$TAG_COMMIT"
    git push --tags
  else
    echo "$TARGET not found!"
  fi
done
