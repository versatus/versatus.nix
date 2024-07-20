{
  description = "Versatus rust-based project template.";

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

    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };

    versatus-nix = {
      url = "github:versatus/versatus.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.fenix.follows = "fenix";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { self, nixpkgs, crane, fenix, flake-utils, advisory-db, versatus-nix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs) lib;

        toolchains = versatus-nix.toolchains.${system};

        rustToolchain = toolchains.mkRustToolchainFromTOML
          ./rust-toolchain.toml
          lib.fakeSha256;

        # Overrides the default crane rust-toolchain with fenix.
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain.fenix-pkgs;
        src = craneLib.cleanCargoSource ./.;

        # Common arguments can be set here to avoid repeating them later
        commonArgs = {
          inherit src;
          strictDeps = true;

          # Inputs that must be available at the time of the build
          nativeBuildInputs = [
            # pkgs.pkg-config # necessary for linking OpenSSL
            # pkgs.clang
          ];

          buildInputs = [
            # Add additional build inputs here
            # pkgs.openssl.dev
          ] ++ [
            # You probably want this.
            rustToolchain.darwin-pkgs
          ] ++ lib.optionals pkgs.stdenv.isDarwin [
            # Additional darwin specific inputs can be set here
          ];

          # Additional environment variables can be set directly
          # LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
          # MY_CUSTOM_VAR = "some value";
        };

        # Build *just* the cargo dependencies, so we can reuse
        # all of that work (e.g. via cachix) when running in CI
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        individualCrateArgs = commonArgs // {
          inherit cargoArtifacts;
          inherit (craneLib.crateNameFromCargoToml { inherit src; }) version;
          doCheck = false; # Use cargo-nextest below.
        };

        fileSetForCrate = crate: lib.fileset.toSource {
          root = ./.;
          fileset = lib.fileset.unions [
            ./Cargo.toml
            ./Cargo.lock
            ./my-common
            ./my-workspace-hack
            crate
          ];
        };

        # Build the top-level crates of the workspace as individual derivations.
        # This allows consumers to only depend on (and build) only what they need.
        # Though it is possible to build the entire workspace as a single derivation,
        # so this is left up to you on how to organize things
        my-cli = craneLib.buildPackage (individualCrateArgs // {
          pname = "my-cli";
          cargoExtraArgs = "-p my-cli"; # specify the package to build
          src = fileSetForCrate ./my-cli;
        });
        my-server = craneLib.buildPackage (individualCrateArgs // {
          pname = "my-server";
          cargoExtraArgs = "-p my-server"; # specify the package to build
          src = fileSetForCrate ./my-server;
        });
      in
      {
        checks = {
          # Build the crate as part of `nix flake check` for convenience
          inherit my-cli my-server;

          # Run clippy (and deny all warnings) on the workspace source,
          # again, reusing the dependency artifacts from above.
          #
          # Note that this is done as a separate derivation so that
          # we can block the CI if there are issues here, but not
          # prevent downstream consumers from building our crate by itself.
          my-workspace-clippy = craneLib.cargoClippy (commonArgs // {
            inherit cargoArtifacts;
            cargoClippyExtraArgs = "--all-targets -- --deny warnings";
          });

          my-workspace-doc = craneLib.cargoDoc (commonArgs // {
            inherit cargoArtifacts;
          });

          # Check formatting
          my-workspace-fmt = craneLib.cargoFmt {
            inherit src;
          };

          # Audit dependencies
          my-workspace-audit = craneLib.cargoAudit {
            inherit src advisory-db;
          };

          # Audit licenses
          my-workspace-deny = craneLib.cargoDeny {
            inherit src;
          };

          # Run tests with cargo-nextest
          # Consider setting `doCheck = false` on other crate derivations
          # if you do not want the tests to run twice
          my-workspace-nextest = craneLib.cargoNextest (commonArgs // {
            inherit cargoArtifacts;
            partitions = 1;
            partitionType = "count";
          });

          # Ensure that cargo-hakari is up to date
          my-workspace-hakari = craneLib.mkCargoDerivation {
            inherit src;
            pname = "my-workspace-hakari";
            cargoArtifacts = null;
            doInstallCargoArtifacts = false;

            buildPhaseCargoCommand = ''
              cargo hakari generate --diff  # workspace-hack Cargo.toml is up-to-date
              cargo hakari manage-deps --dry-run  # all workspace crates depend on workspace-hack
              cargo hakari verify
            '';

            nativeBuildInputs = [
              pkgs.cargo-hakari
            ];
          };
        };

        packages = {
          inherit my-cli my-server;
        } // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
          my-workspace-llvm-coverage = craneLib.cargoLlvmCov (commonArgs // {
            inherit cargoArtifacts;
          });
        };

        apps = {
          my-cli = flake-utils.lib.mkApp {
            drv = my-cli;
          };
          my-server = flake-utils.lib.mkApp {
            drv = my-server;
          };
        };

        devShells.default = craneLib.devShell {
          # Inherit inputs from checks.
          checks = self.checks.${system};

          # Additional dev-shell environment variables can be set directly
          # MY_CUSTOM_DEVELOPMENT_VAR = "something else";

          # Extra inputs can be added here; cargo and rustc are provided by default.
          #
          # In addition, these packages and the `rustToolchain` are inherited from checks above:
          # cargo-audit
          # cargo-deny
          # cargo-nextest
          # cargo-hakari
          packages = with pkgs; [
            # ripgrep
            nil # nix lsp
            nixpkgs-fmt # nix formatter
          ];
        };

        formatter = pkgs.nixpkgs-fmt;
      });
}
