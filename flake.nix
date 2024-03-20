{
  description =
    "A Nix flake for the Versatus labs ecosystem that builds Versatus binaries and provides
    development environments for building on Versatus repositories for supported systems.";

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

    lasr = {
      url = "github:versatus/lasr";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, crane, fenix, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        inherit (pkgs) lib;

        versatus = self.inputs.versatus;
        lasr = self.inputs.lasr;
        craneLib = crane.lib.${system};
        versaSrc = craneLib.cleanCargoSource (craneLib.path (builtins.toString versatus));
        lasrSrc = craneLib.cleanCargoSource (craneLib.path (builtins.toString lasr));

        rustToolchain = pkgs.callPackage ./dev/rust-toolchain.nix { inherit fenix; inherit versatus; };
        haskellToolchain = pkgs.callPackage ./dev/haskell-toolchain.nix pkgs;

        # Dependency packages to build the entire protocol workspace
        protocolArgs = {
          src = versaSrc;
          strictDeps = true;

          # Inputs that must be available at the time of the build
          nativeBuildInputs = with pkgs; [
            pkg-config # necessary for linking OpenSSL
            clang
          ];

          buildInputs = with pkgs; [
            rocksdb
            openssl.dev
          ] ++ [ rustToolchain.darwin-pkgs ];
          
          LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
          ROCKSDB_LIB_DIR = "${pkgs.rocksdb}/lib";
        };

        lasrArgs = {
          src = lasrSrc;
          strictDeps = true;
          buildInputs = [ rustToolchain.darwin-pkgs ];
        };

        # Overrides the default crane rust-toolchain with fenix.
        craneLibLlvmTools = craneLib.overrideToolchain rustToolchain.fenix-pkgs;

        # Build *just* the cargo dependencies, so we can reuse
        # all of that work (e.g. via cachix) when running in CI
        protocolDeps = craneLib.buildDepsOnly protocolArgs;
        lasrDeps = craneLib.buildDepsOnly lasrArgs;

        # Build the actual crate itself, reusing the dependency
        # artifacts from above.
        versaNodeDrv = craneLib.buildPackage (protocolArgs // {
          doCheck = false; # disables `cargo test` during `nix flake check`
          cargoArtifacts = protocolDeps;
          cargoExtraArgs = "--locked --bin versa";
        });
        lasrNodeDrv = craneLib.buildPackage (lasrArgs // {
          doCheck = false;
          cargoArtifacts = lasrDeps;
          cargoExtraArgs = "--locked --bin lasr_node";
        });
      in
      {
        versaNodeChecks = {
          # Build the crates as part of `nix flake check` for convenience
          versaNodeBuild = versaNodeDrv;

          # Run clippy (and deny all warnings) on the crate source,
          # again, resuing the dependency artifacts from above.
          #
          # Note that this is done as a separate derivation so that
          # we can block the CI if there are issues here, but not
          # prevent downstream consumers from building our crate by itself.
          versa-node-clippy = craneLib.cargoClippy (protocolArgs // {
            cargoArtifacts = protocolDeps;
            cargoClippyExtraArgs = "--all-targets -- --deny warnings";
          });

          versa-node-doc = craneLib.cargoDoc (protocolArgs // {
            cargoArtifacts = protocolDeps;
          });

          # Check formatting
          versa-node-fmt = craneLib.cargoFmt {
            src = versaSrc;
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

        lasrNodeChecks = {
          # Build the crates as part of `nix flake check` for convenience
          lasrNodeBuild = lasrNodeDrv;

          # Run clippy (and deny all warnings) on the crate source,
          # again, resuing the dependency artifacts from above.
          #
          # Note that this is done as a separate derivation so that
          # we can block the CI if there are issues here, but not
          # prevent downstream consumers from building our crate by itself.
          # lasr-node-clippy = craneLib.cargoClippy (lasrArgs // {
          #   cargoArtifacts = lasrDeps;
          #   cargoClippyExtraArgs = "--all-targets -- --deny warnings";
          # });

          lasr-node-doc = craneLib.cargoDoc (lasrArgs // {
            cargoArtifacts = lasrDeps;
          });

          # Check formatting
          # lasr-node-fmt = craneLib.cargoFmt {
          #   src = lasrSrc;
          # };

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
          versaNodeBin = versaNodeDrv;
          lasrNodeBin = lasrNodeDrv;
          default = versaNodeBin;
        } // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
          protocol-llvm-coverage = craneLibLlvmTools.cargoLlvmCov (protocolArgs // {
            cargoArtifacts = protocolDeps;
          });
        };

        apps = rec {
          versaNodeBin = flake-utils.lib.mkApp {
            drv = versaNodeDrv;
          };
          lasrNodeBin = flake-utils.lib.mkApp {
            drv = lasrNodeDrv;
          };
          default = versaNodeBin;
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
            buildInputs = rustToolchain.complete;
            shellHook = ''
              echo "Welcome to versatus, happy hacking 🦀"
            '';
          };
          protocol-dev = craneLib.devShell {
            # Inherit inputs from checks.
            checks = self.versaNodeChecks.${system};
            # Explicit rebinding since the environment args aren't
            # inherited from `checks` like the packages are.
            LIBCLANG_PATH = protocolArgs.LIBCLANG_PATH;
            ROCKSDB_LIB_DIR = protocolArgs.ROCKSDB_LIB_DIR;
          };
          lasr-dev = craneLib.devShell { checks = self.lasrNodeChecks.${system}; };
          default = protocol-dev;
        };
      });
}
