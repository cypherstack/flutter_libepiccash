#!/bin/bash

mkdir build
. ./config.sh
ANDROID_NDK_SHA256="769ee342ea75f80619d985c2da990c48b3d8eaf45f48783a2d48870d04b46108"

if [ ! -e "$ANDROID_NDK_ZIP" ]; then
  curl https://dl.google.com/android/repository/android-ndk-r25c-linux.zip -o ${ANDROID_NDK_ZIP}
fi
echo $ANDROID_NDK_SHA256 $ANDROID_NDK_ZIP | sha256sum -c || exit 1
unzip $ANDROID_NDK_ZIP -d $WORKDIR
