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

    # TODO: enable checks
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
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (pkgs) lib;

      # Language toolchains
      rustToolchain = pkgs.callPackage ./dev/rust-toolchain.nix { inherit fenix versatus; };
      haskellToolchain = pkgs.callPackage ./dev/haskell-toolchain.nix pkgs;

      # Overrides the default crane rust-toolchain with fenix.
      craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain.fenix-pkgs;

      # Cargo source files
      versatus = self.inputs.versatus;
      lasr = self.inputs.lasr;
      versaSrc = craneLib.cleanCargoSource (craneLib.path (builtins.toString versatus));
      lasrSrc = craneLib.cleanCargoSource (craneLib.path (builtins.toString lasr));

      # Dependency packages of each binary
      protocolArgs = {
        pname = "versa";
        version = "1";
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
        pname = "lasr_node";
        version = "1";
        src = lasrSrc;
        strictDeps = true;
        nativeBuildInputs = [ pkgs.pkg-config ];
        buildInputs = [ pkgs.openssl.dev rustToolchain.darwin-pkgs ];
      };

      # Build *just* the cargo dependencies, so we can reuse
      # all of that work (e.g. via cachix) when running in CI
      protocolDeps = craneLib.buildDepsOnly protocolArgs;
      lasrDeps = craneLib.buildDepsOnly lasrArgs;

      # Build the actual crate itself, reusing the dependency
      # artifacts from above.
      versaNodeDrv = craneLib.buildPackage (protocolArgs // {
        pname = "versa";
        version = "1";
        doCheck = false; # disables `cargo test` during `nix flake check`
        cargoArtifacts = protocolDeps;
        cargoExtraArgs = "--locked --bin versa";
      });
      lasrNodeDrv = craneLib.buildPackage (lasrArgs // {
        pname = "lasr_node";
        version = "1";
        doCheck = false;
        cargoArtifacts = lasrDeps;
        cargoExtraArgs = "--locked --bin lasr_node";
      });
      lasrCliDrv = craneLib.buildPackage (lasrArgs // {
        pname = "lasr_cli";
        version = "1";
        doCheck = false;
        cargoArtifacts = lasrDeps;
        cargoExtraArgs = "--locked --bin lasr_cli";
      });
    in
    {
      checks = {
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

        lasrNodeBuild = lasrNodeDrv;

        lasr-node-doc = craneLib.cargoDoc (lasrArgs // {
          cargoArtifacts = lasrDeps;
        });
      };
      
      packages = let
        hostPkgs = pkgs;
        # The linux virtual machine system architecture, derived from the host's environment
        # Example: aarch64-darwin -> aarch64-linux
        guest_system = builtins.replaceStrings [ "darwin" ] [ "linux" ] pkgs.stdenv.hostPlatform.system;
        guest_pkgs = self.packages.${guest_system};
        # Build packages for the linux variant of the host architecture, but preserve the host's
        # version of nixpkgs to build the virtual machine with. This way, building and running a
        # linux virtual environment works for all supported system architectures.
        lasrGuestVM = nixpkgs.lib.nixosSystem {
          system = null;
          modules = [
            ./deployments/lasr_node/common.nix
            ./deployments/lasr_node/nightly/nightly-options.nix
            ({ modulesPath, pkgs, ... }: {
              imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];

              virtualisation = {
                cores = 3;
                # The virtual machine's system architecture
                # Ports are subject to change
                forwardPorts = [
                  { from = "host"; host.port = 2222; guest.port = 22; }
                ];
                # Disk size & RAM may be increased as needed
                diskSize = 32768;
                memorySize = 4096;
                # The host's version of nixpkgs used to build the VM
                host.pkgs = hostPkgs;
              };

              nixpkgs.hostPlatform = guest_system;

              users.users.root.hashedPassword = "";

              services.openssh = {
                enable = true;
                settings.PermitRootLogin = "yes";
                settings.PermitEmptyPasswords = "yes";
              };
              security.pam.services.sshd.allowNullPassword = true;

              # Adding the LASR packages:
              environment.systemPackages = with guest_pkgs; [
                lasr_node
                lasr_cli
              ];

              nix.settings.experimental-features = ["nix-command" "flakes"];
            })
          ];
          specialArgs = {
            lasr_pkgs = with guest_pkgs; {
              lasr_node = lasr_node;
              lasr_cli = lasr_cli;
            };
          };
        };
      in {
        versa = versaNodeDrv;

        lasr_node = lasrNodeDrv;

        lasr_cli = lasrCliDrv;

        lasr_nightly_image =
          self.nixosConfigurations.lasr_nightly.config.system.build.digitalOceanImage;

        # Spin up a virtual machine with the lasr_nightly_image options
        # Useful for quickly debugging or testing changes locally
        lasr_vm = lasrGuestVM.config.system.build.vm;

        # lasr_cli_cross = # this works on Linux only at the moment
        #   let
        #     archPrefix = builtins.elemAt (pkgs.lib.strings.split "-" system) 0;
        #     target = "${archPrefix}-unknown-linux-musl";

        #     staticCraneLib =
        #       let rustMuslToolchain = with fenix.packages.${system}; combine [
        #           minimal.cargo
        #           minimal.rustc
        #           targets.${target}.latest.rust-std
        #         ];
        #       in
        #       (crane.mkLib pkgs).overrideToolchain rustMuslToolchain;

        #     buildLasrCliStatic = { stdenv, pkg-config, openssl, libiconv, darwin }:
        #       staticCraneLib.buildPackage {
        #         pname = "lasr_cli";
        #         version = "1";
        #         src = lasrSrc;
        #         strictDeps = true;
        #         nativeBuildInputs = [ pkg-config ];
        #         buildInputs = [
        #           (openssl.override { static = true; })
        #           rustToolchain.darwin-pkgs
        #         ];

        #         doCheck = false;
        #         cargoExtraArgs = "--locked --bin lasr_cli";

        #         CARGO_BUILD_TARGET = target;
        #         CARGO_BUILD_RUSTFLAGS = "-C target-feature=+crt-static";
        #       };
        #   in
        #   pkgs.pkgsMusl.callPackage buildLasrCliStatic {}; # TODO: needs fix, pkgsMusl not available on darwin systems

        # TODO: Getting CC linker error
        # lasr_cli_windows =
        #   let
        #     crossPkgs = import nixpkgs {
        #       crossSystem = pkgs.lib.systems.examples.mingwW64;
        #       localSystem = system;
        #     };
        #     craneLib = 
        #       let 
        #         rustToolchain = with fenix.packages.${system}; combine [
        #             minimal.cargo
        #             minimal.rustc
        #             targets.x86_64-pc-windows-gnu.latest.rust-std
        #           ];
        #       in
        #       (crane.mkLib crossPkgs).overrideToolchain rustToolchain;

        #     inherit (crossPkgs.stdenv.targetPlatform.rust)
        #       cargoEnvVarTarget cargoShortTarget;

        #     buildLasrCli = { stdenv, pkg-config, openssl, libiconv, windows }:
        #       craneLib.buildPackage {
        #         pname = "lasr_node";
        #         version = "1";
        #         src = lasrSrc;
        #         strictDeps = true;
        #         nativeBuildInputs = [ pkg-config ];
        #         buildInputs = [
        #           (openssl.override { static = true; })
        #           windows.pthreads
        #         ];

        #         doCheck = false;
        #         cargoExtraArgs = "--locked --bin lasr_cli";

        #         CARGO_BUILD_TARGET = cargoShortTarget;
        #         CARGO_BUILD_RUSTFLAGS = "-C target-feature=+crt-static";
        #         "CARGO_TARGET_${cargoEnvVarTarget}_LINKER" = "${stdenv.cc.targetPrefix}cc";
        #         HOST_CC = "${stdenv.cc.nativePrefix}cc";
        #       };
        #   in
        #   crossPkgs.callPackage buildLasrCli {};

      } // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
        protocol-llvm-coverage = craneLib.cargoLlvmCov (protocolArgs // {
          cargoArtifacts = protocolDeps;
        });
      };

      # apps = rec {
      #   versaNodeBin = flake-utils.lib.mkApp {
      #     name = "versa";
      #     drv = versaNodeDrv;
      #   };
      #   lasrNodeBin = flake-utils.lib.mkApp {
      #     name = "lasr_node";
      #     drv = lasrNodeDrv;
      #   };
      #   default = versaNodeBin;
      # };

      devShells = rec {
        default = nix-dev;
        # Developer environments for Versatus repos
        protocol-dev = craneLib.devShell {
          # Inherit inputs from checks.
          checks = { inherit (self.checks.${system}) versaNodeBuild; };
          # Explicit rebinding since the environment args aren't
          # inherited from `checks` like the packages are.
          LIBCLANG_PATH = protocolArgs.LIBCLANG_PATH;
          ROCKSDB_LIB_DIR = protocolArgs.ROCKSDB_LIB_DIR;
        };
        lasr-dev = craneLib.devShell {
          checks = { inherit (self.checks.${system}) lasrNodeBuild; };
        };
        nix-dev = pkgs.mkShell {
          buildInputs = with pkgs; [
            nil
            nixpkgs-fmt
          ];
        };

        # Language developer environments for building smart contracts
        # with Versatus language SDKs
        versa-rs = pkgs.mkShell {
          buildInputs = rustToolchain.complete;
          shellHook = ''
            echo "Welcome to versatus, happy hacking 🦀"
          '';
        };
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
      };
    }) // {
      nixosConfigurations.lasr_nightly = let
        system = flake-utils.lib.system.x86_64-linux;
        nightly_pkgs = self.packages.${system};
      in
      nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./deployments/lasr_node/common.nix
          ./deployments/lasr_node/nightly/nightly-options.nix
          ({ modulesPath, ... }: {
            imports = [ ./deployments/digital-ocean/digital-ocean-image.nix ];

            # Adding the LASR packages:
            environment.systemPackages = with nightly_pkgs; [
              lasr_node
              lasr_cli
            ];
          })
        ];
        specialArgs = {
          lasr_pkgs = with nightly_pkgs; {
            lasr_node = lasr_node;
            lasr_cli = lasr_cli;
          };
        };
      };
    }; 
}
