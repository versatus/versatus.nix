{ pkgs, ... }:
let
  # TODO: Pull dockerhub images declaratively.
  # Pull the PD server image from dockerhub
  # pd-image-tar = pkgs.dockerTools.pullImage {
  #   imageName = "pingcap/pd";
  #   imageDigest = "sha256:0e87d077d0fd92903e26a6ebeda633d6979380aac6fc76aa24c6a02d25a404f6";
  #   sha256 = "sha256-vYz5zpWuFlOao8NCrfexfmF5+5kp4j0FDslRC1VSExU=";
  #   finalImageTag = "latest";
  #   finalImageName = "pd";
  # };
  # Starts the placement driver server for TiKV
  pd-server = pkgs.writeShellScriptBin "pd-server.sh" ''
    docker run -d --name pd-server --network host pingcap/pd:latest \
        --name="pd1" \
        --data-dir="/pd1" \
        --client-urls="http://0.0.0.0:2379" \
        --peer-urls="http://0.0.0.0:2380" \
        --advertise-client-urls="http://0.0.0.0:2379" \
        --advertise-peer-urls="http://0.0.0.0:2380"
  '';

  # Pull the TiKV server image from dockerhub
  # tikv-image-tar = pkgs.dockerTools.pullImage {
  #   imageName = "pingcap/tikv";
  #   imageDigest = "sha256:e68889611930cc054acae5a46bee862c4078af246313b414c1e6c4671dceca63";
  #   sha256 = "sha256-ZM+6nZKBnN9aUZ8g9aw+20hV3i1RpMSjEVNLz1OOf0E=";
  #   finalImageTag = "latest";
  #   finalImageName = "tikv";
  # };
  # Starts the TiKV server
  tikv-server = pkgs.writeShellScriptBin "tikv-server.sh" ''
    docker run -d --name tikv-server --network host pingcap/tikv:latest \
        --addr="127.0.0.1:20160" \
        --advertise-addr="127.0.0.1:20160" \
        --data-dir="/tikv" \
        --pd="http://127.0.0.1:2379"
  '';
in
{
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
  ] ++ [
    pd-server
    tikv-server
  ];

  # Enable docker socket
  virtualisation.docker.enable = true;
  users.users.root.extraGroups = [ "docker" ];

  # Before changing, read this first:
  # https://nixos.org/manual/nixos/stable/options.html#opt-system.stateVersion
  system.stateVersion = "24.04";
}
