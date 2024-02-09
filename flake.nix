{
  description =
    "A Nix flake for the Versatus labs ecosystem that builds Versatus binaries and provides
    development environments for building on Versatus repositories for supported systems.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs: let
    # Set of packages for managing Rust toolchain
    fenix-rust = import (fetchTarball {
      url = "https://github.com/nix-community/fenix/archive/main.tar.gz";
      sha256 = "sha256:003pgd0fg9n8j1wz4yg00yfij0lmy8w47dyn4zaljxhqhfbfmbxp";
    }) {};
    rust-toolchain = (fenix-rust.fromToolchainFile { dir = ./.; });

    # Updates the systems that Versatus binaries support
    # and dev-shells can be built for
    flake-utils.supportedSystem = [
      "x86_64-linux"
      "x86_64-openbsd"
      "x86_64-darwin"
      "x86_64-windows"
      "aarch64-linux"
      "aarch64-darwin"
      "riscv64-linux"
    ];
    flake-utils.eachSupportedSystem =
      inputs.flake-utils.lib.eachSystem flake-utils.supportedSystem;

    # @Function
    #
    # @Input: `nixpkgs`
    # @Output: Attribute set of dev-shells
    mkDevShells = pkgs: rec {
      protocol-dev = pkgs.mkShell {
        name = "protocol-dev";
        nativeBuildInputs = [
          rust-toolchain
          pkgs.pkg-config
          pkgs.clang
        ];
        buildInputs = with pkgs; [
          rocksdb
          openssl.dev
          libiconv
        ] ++ lib.optionals stdenv.isDarwin [
          darwin.apple_sdk.frameworks.Security
          darwin.apple_sdk.frameworks.SystemConfiguration
        ];
        shellHook = ''
          export LIBCLANG_PATH="${pkgs.libclang.lib}/lib";
          export ROCKSDB_LIB_DIR="${pkgs.rocksdb}/lib";
        '';
      };

      default = protocol-dev;
    };

    # @Function
    #
    # @Input: `currentSystem` specified by `supportedSystem`
    # @Output: builds `devShell`s & Versatus packages 
    mkOutput = system: let
      pkgs = import inputs.nixpkgs { inherit system; };
    in {
      # TODO: add mkPackages as part of output
      # packges = mkPackages pkgs;
      devShells = mkDevShells pkgs;
      formatter = pkgs.alejandra;
    };

    # The output for each system.
    systemOutputs = flake-utils.eachSupportedSystem mkOutput;
  in
    systemOutputs // { inherit flake-utils; };
}
