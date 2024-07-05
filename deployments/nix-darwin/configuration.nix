{ system, pkgs, lib, rev, ... }:
{
  # Packages that will be installed on your system.
  environment.systemPackages = with pkgs; [
    helix # or your favorite editor
    nil # nix lsp
  ];

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  nix.settings = {
    # Necessary for using flakes on this system.
    experimental-features = "nix-command flakes";
    # Necessary for using `linux-builder`.
    trusted-users = [ "root" "@admin" ];
  };

  # Use the path to `nixpkgs` in `inputs` as $NIX_PATH
  nix.nixPath = lib.mkForce [ "nixpkgs=${pkgs.path}" ];

  # Linux VM launchd service
  nix.linux-builder.enable = true;

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true;

  # Set Git commit hash for darwin-version.
  system.configurationRevision = rev;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = system;
}

