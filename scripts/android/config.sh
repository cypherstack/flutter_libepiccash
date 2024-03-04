#!/bin/bash

export WORKDIR="$(pwd)/"build
export CACHEDIR="$(pwd)/"cache
export ANDROID_NDK_API=21
# r21e also works and was the preferred before.
export ANDROID_NDK_SHA256="8381c440fe61fcbb01e209211ac01b519cd6adf51ab1c2281d5daad6ca4c8c8c"
export ANDROID_NDK_URL=https://dl.google.com/android/repository/android-ndk-r${ANDROID_NDK_API}-linux.zip
# Some NDK versions end in -linux.zip, some in -linux_x86_64.zip.
export ANDROID_NDK_ZIP=${CACHEDIR}/android-ndk-r${ANDROID_NDK_API}-linux.zip
export ANDROID_NDK_ROOT=${WORKDIR}/android-ndk-r${ANDROID_NDK_API}
export ANDROID_NDK_HOME=$ANDROID_NDK_ROOT

# Hacky fix which we will probably have to revisit and fix later.
export ANDROID_NDK_ROOT=~/Android/Sdk/ndk/21.1.6352462
export PATH=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin:$ANDROID_NDK_ROOT/toolchains/arm-linux-androideabi-4.9/prebuilt/linux-x86_64/bin:$PATH
    ./Configure android-arm64 -D__ANDROID_API__=21
