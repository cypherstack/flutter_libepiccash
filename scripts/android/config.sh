#!/bin/bash

export WORKDIR="$(pwd)/"build
export CACHEDIR="$(pwd)/"cache
ANDROID_NDK_API=20b

export ANDROID_NDK_SHA256="8381c440fe61fcbb01e209211ac01b519cd6adf51ab1c2281d5daad6ca4c8c8c"
export ANDROID_NDK_URL=https://dl.google.com/android/repository/android-ndk-r${ANDROID_NDK_API}-linux-x86_64.zip
# Some NDK versions end in -linux.zip, some in -linux_x86_64.zip.
export ANDROID_NDK_ZIP=${CACHEDIR}/android-ndk-r${ANDROID_NDK_API}-linux.zip
export ANDROID_NDK_ROOT=${WORKDIR}/android-ndk-r${ANDROID_NDK_API}
export ANDROID_NDK_HOME=$ANDROID_NDK_ROOT
