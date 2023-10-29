#!/bin/bash

export API=21
export WORKDIR="$(pwd)/"build
#r21e also works and was the preferred before
export ANDROID_NDK_ZIP=${WORKDIR}/android-ndk-r26-linux.zip
export ANDROID_NDK_ROOT=${WORKDIR}/android-ndk-r26
export ANDROID_NDK_HOME=$ANDROID_NDK_ROOT
