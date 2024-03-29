#!/bin/bash

mkdir openssl

. ./config.sh
OPENSSL_SHA256="83c7329fe52c850677d75e5d0b0ca245309b97e8ecbcfdc1dfdc4ab9fac35b39"
OPENSSL_DIR=${WORKDIR}/openssl
OPENSSL_GZIP=${CACHEDIR}/openssl-3.2.1.tar.gz

# shellcheck disable=SC2164
cd $WORKDIR
if [ ! -e "$OPENSSL_GZIP" ]; then
  curl https://www.openssl.org/source/openssl-3.2.1.tar.gz -o "${OPENSSL_GZIP}"
fi
echo $OPENSSL_SHA256 "$OPENSSL_GZIP" | sha256sum -c || exit 1
mkdir -p ${OPENSSL_DIR}
tar -xvzf $OPENSSL_GZIP -C ${OPENSSL_DIR}

# shellcheck disable=SC2164
cd ${OPENSSL_DIR}/openssl-3.2.1
archs=(android-arm android-arm64 android-x86_64)

# shellcheck disable=SC2068
for arch in ${archs[@]}; do
    # Hacky fix which we will probably have to revisit later.
    export ANDROID_NDK_ROOT=~/Android/Sdk/ndk/21.1.6352462
    export PATH=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin:$ANDROID_NDK_ROOT/toolchains/arm-linux-androideabi-4.9/prebuilt/linux-x86_64/bin:$PATH
    ./Configure android-arm64 -D__ANDROID_API__=21
done
