{
  description = "A Nix flake for the Versatus labs ecosystem";

   inputs = {
    pkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # rust toolchain provider
    fenix-rust = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "pkgs";
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
    flake-utils.eachSupportedSystem =
      inputs.flake-utils.lib.eachSystem flake-utils.supportedSystem;
    pkgs = pkgs.legacyPackages.${flake-utils.eachSupportedSystem};
    
  in rec {
    devShells.${flake-utils.eachSupportedSystem}.default =
      pkgs.mkShell
      {
        buildInputs = [
          pkgs.rustc
          pkgs.rustup
          pkgs.rustfmt
        ];

        shellHook = ''
        echo "let's see"
        '';
      };
  };
}



