#!/bin/bash

export WORKDIR="$(pwd)/"build
export CACHEDIR="$(pwd)/"cache
export ANDROID_NDK_API=25c
# r21e also works and was the preferred before.
export ANDROID_NDK_SHA256="769ee342ea75f80619d985c2da990c48b3d8eaf45f48783a2d48870d04b46108"
export ANDROID_NDK_URL=https://dl.google.com/android/repository/android-ndk-r${ANDROID_NDK_API}-linux.zip
# Some NDK versions end in -linux.zip, some in -linux_x86_64.zip.
export ANDROID_NDK_ZIP=${CACHEDIR}/android-ndk-r${ANDROID_NDK_API}-linux.zip
export ANDROID_NDK_ROOT=${WORKDIR}/android-ndk-r${ANDROID_NDK_API}
export ANDROID_NDK_HOME=$ANDROID_NDK_ROOT

# Hacky fix which we will probably have to revisit and fix later.
export ANDROID_NDK_ROOT=~/Android/Sdk/ndk/21.1.6352462
export PATH=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin:$ANDROID_NDK_ROOT/toolchains/arm-linux-androideabi-4.9/prebuilt/linux-x86_64/bin:$PATH
