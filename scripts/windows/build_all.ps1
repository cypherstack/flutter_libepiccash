# !/bin/pwsh

New-Item -ItemType Directory -Force -Path build
$env:COMMIT = $(git log -1 --pretty=format:"%H")
$env:VERSIONS_FILE = "..\..\lib\git_versions.dart"
$env:EXAMPLE_VERSIONS_FILE = "..\..\lib\git_versions_example.dart"
Copy-Item $env:EXAMPLE_VERSIONS_FILE -Destination $env:VERSIONS_FILE -Force
$env:OS = "WINDOWS"
(Get-Content $env:VERSIONS_FILE).replace('WINDOWS_VERSION = ""', "WINDOWS_VERSION = ""${env:COMMIT}""") | Set-Content $env:VERSIONS_FILE
Copy-Item "..\..\rust\*" -Destination "build\rust" -Force -Recurse
cd build\rust
if (Test-Path 'env:IS_ARM ') {
    echo "Building arm version"
    cargo build --target aarch64-unknown-linux-gnu --release --lib

    New-Item -ItemType Directory -Force -Path target\x86_64-unknown-windows\release
    Copy-Item "target\aarch64-unknown-linux-gnu\release\libepic_cash_wallet.so" -Destination "target\x86_64-unknown-linux-gnu\release\" -Force
} else {
    echo "Building x86_64 version"
    cargo build --target x86_64-unknown-linux-gnu --release --lib
}

# Return to /scripts/windows
cd ..
cd ..
