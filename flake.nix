{
  description = "A Nix flake for the Versatus labs ecosystem";

   inputs = {
    pkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # rust toolchain provider
    fenix-rust = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: let
    flake-utils.supportedSystem = [
      "x86_64-linux"
      "x86_64-openbsd"
      "x86_64-darwin"
      "x86_64-windows"
      "aarch64-linux"
      "aarch64-darwin"
      "riscv64-linux"
    ];

  #   flake-utils.eachSupportedSystem =
  #     inputs.flake-utils.lib.eachSystem flake-utils.supportedSystem

  #   mkOutput = system: let
  #     overlays = [inputs.rust-overlay.overlays.default];
  #     pkgs = import inputs.nixpkgs {inherit overlays system;};
  #   in rec {
  #     packages = mkPackages pkgs;
  #     devShells = mkDevShells pkgs packages;
  #     formatter = pkgs.alejandra;
  #   };

  #   # The output for each system.
  #   systemOutputs = utils.eachSupportedSystem mkOutput;
  # in
  #   # Merge the outputs and overlays.
  #   systemOutputs // {inherit overlays utils;};
}



