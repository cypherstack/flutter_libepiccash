#!/bin/bash

mkdir build
. ./config.sh
ANDROID_NDK_SHA1="d3bef08e0e43acd9e7815538df31818692d548bb"

if [ ! -e "$ANDROID_NDK_ZIP" ]; then
  curl https://dl.google.com/android/repository/android-ndk-r26-linux.zip -o ${ANDROID_NDK_ZIP}
fi
echo $ANDROID_NDK_SHA1 $ANDROID_NDK_ZIP | sha1sum -c || exit 1
unzip $ANDROID_NDK_ZIP -d $WORKDIR
