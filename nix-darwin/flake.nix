{
  description = "example nix-darwin config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nix-darwin, nixpkgs, flake-utils }:
    let
      host-name = "macos"; # [user@host:~]$ <- The host part.
      system = flake-utils.lib.system.aarch64-darwin; # Your system architecture, eg. x86_64-darwin.
      pkgs = nixpkgs.legacyPackages.${system}; # Packages inherent of your system.
      inherit (pkgs) lib;

      # Your system's configuration, where packages
      # can be installed, and options can be enabled.
      # System options that result from the configuration
      # can be found at `/etc/nix/nix.conf`. Packages
      # are installed to the `nix-store` volume.
      configuration = import ./configuration.nix {
        inherit system pkgs lib;
        rev = self.rev or self.dirtyRev or null;
      };
    in
    {
      # Rebuild darwin flake using:
      # $ darwin-rebuild switch --flake .
      darwinConfigurations."${host-name}" = nix-darwin.lib.darwinSystem {
        modules = [ configuration ];
      };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."${host-name}".pkgs;
    };
}
