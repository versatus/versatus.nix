{
  description = "Build a cargo project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-analyzer-src.follows = "";
    };

    flake-utils.url = "github:numtide/flake-utils";

    # advisory-db = {
    #   url = "github:rustsec/advisory-db";
    #   flake = false;
    # };

    versatus = {
      url = "github:versatus/versatus";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, crane, fenix, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        inherit (pkgs) lib;

        versatus = self.inputs.versatus;
        craneLib = crane.lib.${system};
        src = craneLib.cleanCargoSource (craneLib.path (builtins.toString versatus));

        rustToolchain = pkgs.callPackage ./dev/rust-toolchain.nix { inherit fenix; inherit versatus; };
        haskellToolchain = pkgs.callPackage ./dev/haskell-toolchain.nix pkgs;

        protocolArgs = {
          inherit src;
          strictDeps = true;

          nativeBuildInputs = with pkgs; [
            # Inputs that must be available at the time of the build
            pkg-config # necessary for linking OpenSSL
            clang
          ];

          buildInputs = with pkgs; [
            # Add additional build inputs here
            rocksdb
            openssl.dev
          ] ++ lib.optionals stdenv.isDarwin [
            # Additional darwin specific inputs
            libiconv
            darwin.apple_sdk.frameworks.Security
            darwin.apple_sdk.frameworks.SystemConfiguration
          ];

          LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
          ROCKSDB_LIB_DIR = "${pkgs.rocksdb}/lib";
        };

        # Overrides the default crane rust-toolchain with fenix.
        craneLibLLvmTools = craneLib.overrideToolchain rustToolchain;

        # Build *just* the cargo dependencies, so we can reuse
        # all of that work (e.g. via cachix) when running in CI
        cargoArtifacts = craneLib.buildDepsOnly protocolArgs;

        # Build the actual crates itself, reusing the dependency
        # artifacts from above.
        #
        # TODO: add args to package build for each bin
        # right now this just builds the entire workspace
        versatusDrv = craneLib.buildPackage (protocolArgs // {
          doCheck = false; # disables `cargo test` during `nix flake check`
          inherit cargoArtifacts;
        });
      in
      {
        checks = {
          # Build the crates as part of `nix flake check` for convenience
          versatusProtocolBuild = versatusDrv;

          # Run clippy (and deny all warnings) on the crate source,
          # again, resuing the dependency artifacts from above.
          #
          # Note that this is done as a separate derivation so that
          # we can block the CI if there are issues here, but not
          # prevent downstream consumers from building our crate by itself.
          versatus-clippy = craneLib.cargoClippy (protocolArgs // {
            inherit cargoArtifacts;
            cargoClippyExtraArgs = "--all-targets -- --deny warnings";
          });

          versatus-doc = craneLib.cargoDoc (protocolArgs // {
            inherit cargoArtifacts;
          });

          # Check formatting
          versatus-fmt = craneLib.cargoFmt {
            inherit src;
          };

          # Audit dependencies
          # my-crate-audit = craneLib.cargoAudit {
          #   inherit src advisory-db;
          # };

          # # Audit licenses
          # my-crate-deny = craneLib.cargoDeny {
          #   inherit src;
          # };

          # Run tests with cargo-nextest
          # Consider setting `doCheck = false` on `my-crate` if you do not want
          # the tests to run twice
          # my-crate-nextest = craneLib.cargoNextest (commonArgs // {
          #   inherit cargoArtifacts;
          #   partitions = 1;
          #   partitionType = "count";
          # });
        };

        packages = rec {
          versa-pkgs = versatusDrv;
          default = versa-pkgs;
        } // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
          my-crate-llvm-coverage = craneLibLLvmTools.cargoLlvmCov (protocolArgs // {
            inherit cargoArtifacts;
          });
        };

        apps.default = flake-utils.lib.mkApp {
          drv = versatusDrv;
        };

        devShells = rec {
          versa-hs = pkgs.mkShell {
            name = "versa-hs";
            buildInputs = haskellToolchain;
            # Make external Nix c libraries like zlib known to GHC, like
            # `pkgs.haskell.lib.buildStackProject` does
            # https://github.com/NixOS/nixpkgs/blob/d64780ea0e22b5f61cd6012a456869c702a72f20/pkgs/development/haskell-modules/generic-stack-builder.nix#L38
            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath haskellToolchain;
            shellHook = ''
              echo "Welcome to versa-hs, happy hacking 🪲" 
            '';
          };
          versa-rs = pkgs.mkShell {
            buildInputs = [ rustToolchain ] ++ (with pkgs; lib.optionals stdenv.isDarwin [
            # Additional darwin specific inputs
            libiconv
            darwin.apple_sdk.frameworks.Security
            darwin.apple_sdk.frameworks.SystemConfiguration
          ]);
            shellHook = ''
              echo "Welcome to versatus, happy hacking 🦀"
            '';
          };
          protocol-dev = craneLib.devShell {
            # Inherit inputs from checks.
            checks = self.checks.${system};
            # Explicit rebinding since the environment args aren't
            # inherited from `checks` like the packages are.
            LIBCLANG_PATH = protocolArgs.LIBCLANG_PATH;
            ROCKSDB_LIB_DIR = protocolArgs.ROCKSDB_LIB_DIR;
          };
          default = protocol-dev;
        };
      });
}
