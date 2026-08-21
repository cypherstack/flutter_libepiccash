#!/usr/bin/env bash
# Build the iOS Simulator (arm64) slice of libepic_cash_wallet and package it
# together with the existing device slice (ios/libs/libepic_cash_wallet.a,
# produced by build_all.sh or download.sh) into an XCFramework.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DEVICE_LIB="${PLUGIN_ROOT}/ios/libs/libepic_cash_wallet.a"
if [ ! -f "${DEVICE_LIB}" ]; then
    echo "Error: ${DEVICE_LIB} not found."
    echo "Run scripts/ios/build_all.sh or scripts/ios/download.sh first to produce the device slice."
    exit 1
fi

mkdir -p "${SCRIPT_DIR}/build"
echo ''$(git log -1 --pretty=format:"%H")' '$(date) >> "${SCRIPT_DIR}/build/git_commit_version.txt"

VERSIONS_FILE="${PLUGIN_ROOT}/lib/git_versions.dart"
EXAMPLE_VERSIONS_FILE="${PLUGIN_ROOT}/lib/git_versions_example.dart"
if [ ! -f "$VERSIONS_FILE" ]; then
    cp "$EXAMPLE_VERSIONS_FILE" "$VERSIONS_FILE"
fi
COMMIT=$(git log -1 --pretty=format:"%H")
OS="IOS"
sed -i '' '/\/\*${OS}_VERSION/c\'$'\n''/\*${OS}_VERSION\*\/ const ${OS}_VERSION = "'"$COMMIT"'";' "$VERSIONS_FILE"

# Copy the rust sources next to this script the same way build_all.sh does.
rm -rf "${SCRIPT_DIR}/build/rust"
cp -r "${PLUGIN_ROOT}/rust" "${SCRIPT_DIR}/build/rust"
cd "${SCRIPT_DIR}/build/rust"

rustup target add aarch64-apple-ios-sim

export IPHONEOS_DEPLOYMENT_TARGET=15.0
export CARGO_TARGET_AARCH64_APPLE_IOS_SIM_RUSTFLAGS="-C link-arg=-mios-simulator-version-min=15.0"
cargo build --release --target aarch64-apple-ios-sim

# Merge librandomx.a (simulator build) with libepic_cash_wallet.a.
SIM_LIB="target/aarch64-apple-ios-sim/release/libepic_cash_wallet.a"
RANDOMX_LIB=$(find target/aarch64-apple-ios-sim/release/build -name "librandomx.a" | head -n 1)
if [ -f "$RANDOMX_LIB" ]; then
    echo "Found RandomX library at: $RANDOMX_LIB"
    libtool -static -o target/aarch64-apple-ios-sim/release/libepic_cash_wallet_combined.a \
        "$SIM_LIB" \
        "$RANDOMX_LIB"
    SIM_LIB=target/aarch64-apple-ios-sim/release/libepic_cash_wallet_combined.a
else
    echo "Warning: librandomx.a not found, using libepic_cash_wallet.a only"
fi

# XCFramework slices must share the same library filename as the device
# slice (libepic_cash_wallet.a); stage the simulator slice accordingly.
SIM_STAGING=target/aarch64-apple-ios-sim/release/sim_staging
rm -rf "$SIM_STAGING"
mkdir -p "$SIM_STAGING"
cp "$SIM_LIB" "$SIM_STAGING/libepic_cash_wallet.a"

# Package device + simulator slices as an XCFramework (both are arm64, so
# lipo cannot combine them).
rm -rf "${PLUGIN_ROOT}/ios/libs/epiccash.xcframework"
xcodebuild -create-xcframework \
    -library "${DEVICE_LIB}" -headers "${PLUGIN_ROOT}/ios/include" \
    -library "${SIM_STAGING}/libepic_cash_wallet.a" -headers "${PLUGIN_ROOT}/ios/include" \
    -output "${PLUGIN_ROOT}/ios/libs/epiccash.xcframework"

echo "Done: ${PLUGIN_ROOT}/ios/libs/epiccash.xcframework"
