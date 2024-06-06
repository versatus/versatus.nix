{ pkgs, ... }:
{
  # Before changing, read this first:
  # https://nixos.org/manual/nixos/stable/options.html#opt-system.stateVersion
  system.stateVersion = "24.04";
  
  # Packages that will be available on the resulting NixOS system.
  # Please keep these in alphabetical order so packages are easy to find.
  environment.systemPackages = with pkgs; [
    curl
    docker
    git
    grpcurl
    gvisor
    kubo
    overmind
    tmux
  ];
}
