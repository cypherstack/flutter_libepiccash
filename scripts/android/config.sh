#!/bin/bash

export WORKDIR="$(pwd)/"build
export CACHEDIR="$(pwd)/"cache
ANDROID_NDK_API=25c

export ANDROID_NDK_SHA256="769ee342ea75f80619d985c2da990c48b3d8eaf45f48783a2d48870d04b46108"
export ANDROID_NDK_URL=https://dl.google.com/android/repository/android-ndk-r${ANDROID_NDK_API}-linux.zip
# Some NDK versions end in -linux.zip, some in -linux_x86_64.zip.
export ANDROID_NDK_ZIP=${CACHEDIR}/android-ndk-r${ANDROID_NDK_API}-linux.zip
export ANDROID_NDK_ROOT=${WORKDIR}/android-ndk-r${ANDROID_NDK_API}
export ANDROID_NDK_HOME=$ANDROID_NDK_ROOT
