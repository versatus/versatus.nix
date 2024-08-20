{
  description =
    "A Nix flake for the Versatus labs ecosystem that builds Versatus binaries and provides
    development environments for building on Versatus repositories for supported systems.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-analyzer-src.follows = "";
    };

    flake-utils.url = "github:numtide/flake-utils";

    nix-watch = {
      url = "github:Cloud-Scythe-Labs/nix-watch";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { self, nixpkgs, fenix, flake-utils, nix-watch, ... }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (pkgs) lib;

          # Virtualisation helpers
          mkGuestSystem = { pkgs, ... }: builtins.replaceStrings [ "darwin" ] [ "linux" ] pkgs.stdenv.hostPlatform.system;

          # Language toolchains
          mkRustToolchainFromTOML = toml_path: hash:
            import ./toolchains/rust-toolchain.nix {
              inherit
                lib
                pkgs
                fenix
                system
                toml_path
                hash;
            };
          mkHaskellToolchain = import ./toolchains/haskell-toolchain.nix;
        in
        {
          # TODO: Abstract this into modules and inherit lib
          lib = {
            # Tools for managing virtual machines.
            virtualisation = {
              # The linux virtual machine system architecture, derived from the host's environment.
              # Example: aarch64-darwin -> aarch64-linux
              inherit mkGuestSystem;
            };
            # Tools for creating project specific toolchains.
            toolchains = {
              inherit
                # Given the path to a `rust-toolchain.toml`, produces the derivation
                # for that toolchain for linux and darwin systems.
                # Useful for rust projects that declare a `rust-toolchain.toml`.
                mkRustToolchainFromTOML
                # Takes nixpkgs as input, provides common haskell tools and automatically
                # resolves paths. Includes LD_LIBRARY_PATH environment variable.
                mkHaskellToolchain;
            };
            # Developer Tools
            devTools = {
              nix-watch = nix-watch.nix-watch.${system}.devTools;
            };
          };

          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nil
              nixpkgs-fmt
            ];
          };

          formatter = pkgs.nixpkgs-fmt;
        }
      ) // {
      nixosModules = {
        deployments = {
          debugVm = ./nixos/modules/deployments/debug-vm.nix;
          digitalOcean = {
            digitalOceanImage = ./nixos/modules/deployments/digital-ocean/digital-ocean-image.nix;
            configuration = ./nixos/modules/deployments/digital-ocean/configuration.nix;
          };
        };
      };

      templates = {
        rust-package = {
          path = ./templates/rust-package;
          description = ''
            Initializes a nix flake that includes the boilerplate code for building
            and developing Versatus' rust-based single-package projects. A workspace
            template is also available: `rust-workspace`.

            `nix flake init -t github:versatus/versatus.nix#rust-package`
          '';
        };
        rust-workspace = {
          path = ./templates/rust-workspace;
          description = ''
            Initializes a nix flake that includes the boilerplate code for building
            and developing Versatus' rust-based workspace projects. A single-package
            template is also available: `rust-package`.

            `nix flake init -t github:versatus/versatus.nix#rust-workspace`
          '';
        };
      };
    };
}
