#!/bin/bash

mkdir openssl

. ./config.sh
OPEN_SSL_SHA256="83c7329fe52c850677d75e5d0b0ca245309b97e8ecbcfdc1dfdc4ab9fac35b39"

#export OPENSSLDIR="$(pwd)/"openssl
#echo OPENSSLDIR
#export OPEN_SSL_GZIP=${OPENSSLDIR}/openssl.tar.gz
# shellcheck disable=SC2164
cd $OPENSSLDIR
if [ ! -e "$OPEN_SSL_GZIP" ]; then
  curl https://www.openssl.org/source/openssl-3.2.1.tar.gz -o "${OPEN_SSL_GZIP}"
fi
echo $OPEN_SSL_SHA256 "$OPEN_SSL_GZIP" | sha256sum -c || exit 1
echo $OPEN_SSL_GZIP
tar -xvzf $OPEN_SSL_GZIP

# shellcheck disable=SC2164
cd openssl-3.2.1
archs=(android-arm android-arm64 android-x86_64)

# shellcheck disable=SC2068
for arch in ${archs[@]}; do

echo  "$ANDROID_NDK_ROOT"
#echo "${WORKDIR}"/android-ndk-r20b
    export ANDROID_NDK_ROOT=~/Android/Sdk/ndk/21.1.6352462
    export PATH=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin:$ANDROID_NDK_ROOT/toolchains/arm-linux-androideabi-4.9/prebuilt/linux-x86_64/bin:$PATH
        ./Configure android-arm64 -D__ANDROID_API__=21
done