{
  description =
    "A Nix flake for the Versatus labs ecosystem that builds Versatus binaries and provides
    development environments for building on Versatus repositories for supported systems.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fenix-rust = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    versatus = {
      url = "github:versatus/versatus";
      flake = false;
    };
  };

  outputs = inputs: let
    # Updates the systems that Versatus binaries support
    # and dev-shells can be built for
    flake-utils.supportedSystem = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    flake-utils.eachSupportedSystem =
      inputs.flake-utils.lib.eachSystem flake-utils.supportedSystem;

    # @Function
    #
    # @Input: `nixpkgs`
    # @Output: Attribute set of dev-shells
    mkDevShells = pkgs: let
      rust-toolchain = pkgs.fenix.fromToolchainFile {
        file = inputs.versatus + "/rust-toolchain.toml";
        sha256 = "sha256-SXRtAuO4IqNOQq+nLbrsDFbVk+3aVA8NNpSZsKlVH/8=";
      };
      # Wrap Stack to work with our Nix integration. We don't want to modify
      # stack.yaml so non-Nix users don't notice anything.
      # --no-nix:         We don't want Stack's way of integrating Nix.
      # --system-ghc:     Use the existing GHC on PATH (will come from this Nix file)
      # --no-install-ghc: Don't try to install GHC if no matching GHC found on PATH
      stack-wrapped = pkgs.symlinkJoin {
        name = "stack"; # will be available as the usual `stack` in terminal
        paths = [ pkgs.stack ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/stack \
            --add-flags "\
              --no-nix \
              --system-ghc \
              --no-install-ghc \
            "
        '';
      };
      # Uses the latest compatible nixpkgs version.
      # Updating nixpkgs with `nix flake update` may break this.
      hs-pkgs = pkgs.haskell.packages.ghc963;
      haskellBuildInputs = [
        stack-wrapped
      ] ++ (with hs-pkgs; [
        ghc
        ghcid
        cabal-install
        ormolu
        hlint
        hoogle
        haskell-language-server
        implicit-hie
        retrie
        zlib
      ]);
    in rec {
      protocol-dev = pkgs.mkShell {
        name = "protocol-dev";
        buildInputs = [
          rust-toolchain
        ] ++ (with pkgs; [
          taplo # toml formatter
          pkg-config
          clang
          rocksdb
          openssl.dev
          libiconv
        ] ++ lib.optionals stdenv.isDarwin [
          darwin.apple_sdk.frameworks.Security
          darwin.apple_sdk.frameworks.SystemConfiguration
        ]);
        shellHook = ''
          export LIBCLANG_PATH="${pkgs.libclang.lib}/lib";
          export ROCKSDB_LIB_DIR="${pkgs.rocksdb}/lib";
        '';
      };

      versa-haskell = pkgs.mkShell {
        name = "versa-haskell";
        buildInputs = haskellBuildInputs;
        # Make external Nix c libraries like zlib known to GHC, like
        # pkgs.haskell.lib.buildStackProject does
        # https://github.com/NixOS/nixpkgs/blob/d64780ea0e22b5f61cd6012a456869c702a72f20/pkgs/development/haskell-modules/generic-stack-builder.nix#L38
        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath haskellBuildInputs;
      };

      default = protocol-dev;
    };

    # @Function
    #
    # @Input: `currentSystem` specified by `supportedSystem`
    # @Output: builds `devShell`s & Versatus packages 
    mkOutput = system: let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ inputs.fenix-rust.overlays.default ];
      };
    in {
      # TODO: add mkPackages as part of output
      # versa-pkgs = mkPackages pkgs;

      # TODO: finalize cross platform rust-toolchain
      # fenix = {
      #   default = pkgs.callPackage ./rust-toolchain.nix {
      #     versatus = inputs.versatus;
      #     rust-toolchain = pkgs.fenix.fromToolchainFile {
      #       file = inputs.versatus + "/rust-toolchain.toml";
      #       sha256 = "sha256-SXRtAuO4IqNOQq+nLbrsDFbVk+3aVA8NNpSZsKlVH/8=";
      #     };
      #   };
      # };
      devShells = mkDevShells pkgs;
      formatter = pkgs.alejandra;
    };

    # The output for each system.
    systemOutputs = flake-utils.eachSupportedSystem mkOutput;
  in
    systemOutputs // { inherit flake-utils; };
}
