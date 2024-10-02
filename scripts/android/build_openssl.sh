#!/bin/bash

. ./config.sh
OPENSSL_VERSION="1.1.1q"
OPENSSL_SHA256="d7939ce614029cdff0b6c20f0e2e5703158a489a72b2507b8bd51bf8c8fd10ca"
OPENSSL_DIR=${WORKDIR}/openssl
OPENSSL_GZIP=${CACHEDIR}/openssl-${OPENSSL_VERSION}.tar.gz

# shellcheck disable=SC2164
cd "${WORKDIR}"
if [ ! -e "$OPENSSL_GZIP" ]; then
  curl -L https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz -o "${OPENSSL_GZIP}"
fi
echo $OPENSSL_SHA256 "$OPENSSL_GZIP" | sha256sum -c || exit 1
mkdir -p "${OPENSSL_DIR}"
tar -xvzf "$OPENSSL_GZIP" -C "${OPENSSL_DIR}"

# needed for when rust tries to build openssl-sys
export PATH=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin:$ANDROID_NDK_ROOT/toolchains/arm-linux-androideabi-4.9/prebuilt/linux-x86_64/bin:$PATH

# shellcheck disable=SC2164
cd "${WORKDIR}"/..
