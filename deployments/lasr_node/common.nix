{ pkgs /*, lasr_node */ }:
{
  environment.systemPackages = with pkgs; [
    curl
    git
    gvisor
    tmux
    overmind
    docker
    kubo
    grpcurl
  ];
  # ] ++ [ lasr_node ];
}
