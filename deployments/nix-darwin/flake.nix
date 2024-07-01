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
    host-name = "macos";                            # [user@host:~]$ <- The host part.
    system = flake-utils.lib.system.aarch64-darwin; # Your system architecture, eg. x86_64-darwin.
    pkgs = nixpkgs.legacyPackages.${system};        # Packages inherent of your system.
    inherit (pkgs) lib;

    configuration = import ./configuration.nix {    # Your system's configuration, where packages
      inherit system pkgs lib;                      # can be installed, and options can be enabled.
      rev = self.rev or self.dirtyRev or null;      # System options that result from the configuration
    };                                              # can be found at `/etc/nix/nix.conf`. Packages
  in                                                # are installed to the `nix-store` volume.
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
