#!/bin/bash

mkdir -p build
. ./config.sh

if [ ! -e "${ANDROID_NDK_ZIP}" ]; then
  mkdir -p cache
  # curl https://dl.google.com/android/repository/android-ndk-r${ANDROID_NDK_API}-linux.zip -o ${ANDROID_NDK_ZIP}
  curl "${ANDROID_NDK_URL}" -o "${ANDROID_NDK_ZIP}"
fi
echo "${ANDROID_NDK_SHA256}" "${ANDROID_NDK_ZIP}" | sha256sum -c || exit 1
unzip "${ANDROID_NDK_ZIP}" -d "${WORKDIR}"
