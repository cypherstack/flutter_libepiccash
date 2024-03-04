#!/bin/bash

export API=21
export WORKDIR="$(pwd)/"build
#r21e also works and was the preferred before
export ANDROID_NDK_ZIP=${WORKDIR}/android-ndk-r20b-linux.zip
export ANDROID_NDK_ROOT=${WORKDIR}/android-ndk-r21e
export ANDROID_NDK_HOME=$ANDROID_NDK_ROOT


export OPENSSLDIR="$(pwd)/"openssl
export OPEN_SSL_GZIP=openssl-3.2.1.tar.gz
