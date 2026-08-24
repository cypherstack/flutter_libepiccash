{
  description = "Reproducible native builds for flutter_libepiccash";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    randomx-rust = {
      url = "git+https://github.com/cypherstack/randomx-rust?rev=5147a05e320a9fb68306ae08a1e94bc9cdd56a77";
      flake = false;
    };
    randomx-core = {
      url = "github:EpicCash/randomx/c62cf2e5d477a73ffb6992564e4d6cb86cd96cb5";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, rust-overlay, randomx-rust, randomx-core }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ (import rust-overlay) ];
          };
          rustToolchain = pkgs.rust-bin.stable."1.89.0".minimal;
          rustPlatform = pkgs.makeRustPlatform {
            cargo = rustToolchain;
            rustc = rustToolchain;
          };
          randomxSource = pkgs.runCommand "randomx-rust-source" { } ''
            cp -a ${randomx-rust} "$out"
            chmod -R u+w "$out"
            rm -rf "$out/randomx"
            cp -a ${randomx-core} "$out/randomx"
          '';
          foundationJson = pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/cypherstack/epic/c592407af7000c0105cf83a0bc7ec7849b9356f4/debian/foundation.json";
            hash = "sha256-Wjp1hBJ90x+6GOrv8cVRv6p0tOUOU3oeGQT+ZzCxf1w=";
          };
          foundationFloonetJson = pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/cypherstack/epic/c592407af7000c0105cf83a0bc7ec7849b9356f4/debian/foundation_floonet.json";
            hash = "sha256-UDpNXM8hTfhnItFMyTwXecVOW4J3c8ii9liIoG8u+60=";
          };
        in {
          epic-cash-wallet = rustPlatform.buildRustPackage {
            pname = "epic-cash-wallet";
            version = "0.1.0";
            src = ./rust;
            cargoHash = "sha256-JVrX4oLtxToFI7vFCJln6knOzVHoKni8lfFksn8I0V4=";

            nativeBuildInputs = with pkgs; [ cmake llvmPackages.libclang perl pkg-config ];
            postPatch = ''
              substituteInPlace Cargo.toml \
                --replace-fail \
                'randomx = { git = "https://github.com/cypherstack/randomx-rust" }' \
                'randomx = { path = "${randomxSource}" }'
            '';
            postConfigure = ''
              foundation_rs="$(find "$NIX_BUILD_TOP" -path '*/epic_core-4.0.0/src/core/foundation.rs' -print -quit)"
              test -n "$foundation_rs"
              epic_workspace="$(dirname "$(dirname "$(dirname "$(dirname "$foundation_rs")")")")"
              install -Dm644 ${foundationJson} "$epic_workspace/debian/foundation.json"
              install -Dm644 ${foundationFloonetJson} "$epic_workspace/debian/foundation_floonet.json"
            '';
            cargoBuildFlags = [ "--lib" ];
            doCheck = false;

            env = {
              LIBCLANG_PATH = "${pkgs.lib.getLib pkgs.llvmPackages.libclang}/lib";
              SOURCE_DATE_EPOCH = "1";
              RUSTFLAGS = "-C debuginfo=0 --remap-path-prefix=/build/source=.";
            };

            installPhase = ''
              runHook preInstall
              library="$(find target -name libepic_cash_wallet.so -print -quit)"
              test -n "$library"
              install -Dm755 "$library" "$out/lib/libepic_cash_wallet.so"
              install -Dm644 target/epic_cash_wallet.h "$out/include/epic_cash_wallet.h"
              runHook postInstall
            '';
          };

          default = self.packages.${system}.epic-cash-wallet;
        });

      checks = forAllSystems (system: {
        inherit (self.packages.${system}) epic-cash-wallet;
      });
    };
}
