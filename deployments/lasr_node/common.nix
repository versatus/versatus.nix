{ pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  # Pull the PD server image from dockerhub
  pd-image = let
    # TODO: Figure out how to automatically generate this.
    sha =
      if system == "aarch64-linux" then "sha256-+IBB5p1M8g3fLjHbF90vSSAoKUidl5cdkpTulkzlMAc="
      else if system == "x86_64-linux" then "sha256-xNPJrv8y6vjAPNvn9lAkghCfRGUDiBfRCUBsEYvb49Q="
      else builtins.throw "Unsupported platform, must either be arm64 or amd64 Linux";
  in
  pkgs.dockerTools.pullImage {
    imageName = "pingcap/pd";
    imageDigest = "sha256:0e87d077d0fd92903e26a6ebeda633d6979380aac6fc76aa24c6a02d25a404f6";
    sha256 = sha;
    finalImageTag = "latest";
    finalImageName = "pingcap/pd";
  };
  # Starts the placement driver server for TiKV.
  start-pd-server = pkgs.writeShellScriptBin "start-pd-server.sh" ''
    docker run -d --name pd-server --network host pingcap/pd:latest \
        --name="pd1" \
        --data-dir="/pd1" \
        --client-urls="http://0.0.0.0:2379" \
        --peer-urls="http://0.0.0.0:2380" \
        --advertise-client-urls="http://0.0.0.0:2379" \
        --advertise-peer-urls="http://0.0.0.0:2380"
  '';
  # Pull the TiKV server image from dockerhub
  tikv-image = let
    # TODO: Figure out how to automatically generate this.
    sha =
      if system == "aarch64-linux" then "sha256-JbogHq9FLfm7x08xkwiDF0+YyUKRXF34vHty+ZxIZh0="
      else if system == "x86_64-linux" then "sha256-udLF3mAuUU08QX2Tg/mma9uu0JdtdJuxK3R1bqdKjKk="
      else builtins.throw "Unsupported platform, must either be arm64 or amd64 Linux";
  in
  pkgs.dockerTools.pullImage {
    imageName = "pingcap/tikv";
    imageDigest = "sha256:e68889611930cc054acae5a46bee862c4078af246313b414c1e6c4671dceca63";
    sha256 = sha;
    finalImageTag = "latest";
    finalImageName = "pingcap/tikv";
  };
  # Starts the TiKV server.
  start-tikv-server = pkgs.writeShellScriptBin "start-tikv-server.sh" ''
    docker run -d --name tikv-server --network host pingcap/tikv:latest \
        --addr="127.0.0.1:20160" \
        --advertise-addr="127.0.0.1:20160" \
        --data-dir="/tikv" \
        --pd="http://127.0.0.1:2379"
  '';

  # Creates the working directory, scripts & initializes the IPFS node.
  setup-working-dir = pkgs.writeShellScriptBin "setup-working-dir.sh" ''
    if [ -e "/app" ]; then
      echo "Working directory already exists."
      exit 0
    fi

    mkdir -p /app/bin
    mkdir -p /app/tmp/kubo

    cd /app
    printf "${procfile.text}" > "${procfile.name}"
    git clone https://github.com/versatus/lasr.git

    cd /app/bin
    printf "${start-ipfs.text}" > "${start-ipfs.name}"
    printf "${start-lasr.text}" > "${start-lasr.name}"
    printf "${start-overmind.text}" > "${start-overmind.name}"

    for file in ./*; do
      chmod +x "$file"
    done

    cd /app/tmp/kubo
    export IPFS_PATH=/app/tmp/kubo
    ipfs init

    echo "Done"
    exit 0
  '';

  # Initializes lasr_node environment variables and persists them between system boots.
  init-env = pkgs.writeShellScriptBin "init-env.sh" ''
    secret_key=$(lasr_cli wallet new | jq '.secret_key')
    block_path="/app/blocks_processed.dat"
    eth_rpc_url="https://u0anlnjcq5:xPYLI9OMwxRqJZqhfgEiKMeGdpVjGduGKmMCNBsu46Y@u0auvfalma-u0j1mdxq0w-rpc.us0-aws.kaleido.io/" 
    eo_contract=0x563f0efeea703237b32ae7f66123b864f3e46a3c
    compute_rpc_url=ws://localhost:9125 
    storage_rpc_url=ws://localhost:9126
    batch_interval=180
    echo "set -o noclobber" >> /etc/profile
    echo "export SECRET_KEY=$secret_key" >> /etc/profile
    echo "export BLOCKS_PROCESSED_PATH=$block_path" >> /etc/profile
    echo "export ETH_RPC_URL=$eth_rpc_url" >> /etc/profile
    echo "export EO_CONTRACT_ADDRESS=$eo_contract" >> /etc/profile
    echo "export COMPUTE_RPC_URL=$compute_rpc_url" >> /etc/profile
    echo "export STORAGE_RPC_URL=$storage_rpc_url" >> /etc/profile
    echo "export BATCH_INTERVAL=$batch_interval" >> /etc/profile
    source /etc/profile
  '';

  # Starts kubo IPFS daemon.
  start-ipfs = pkgs.writeTextFile {
    name = "start-ipfs.sh";
    text = ''
      IPFS_PATH=/app/tmp/kubo ipfs daemon
    '';
    executable = true;
    destination = "/app/bin/start-ipfs.sh";
  };

  # TODO: Remove this and use either the cargo target bin, or nix bin directly.
  # Starts the lasr_node from the release build.
  start-lasr = pkgs.writeTextFile {
    name = "start-lasr.sh";
    text = ''
      PREFIX=/app/lasr
      cd $PREFIX

      lasr_node
    '';
    executable = true;
    destination = "/app/bin/start-lasr.sh";
  };

  # Main process script. Re/starts the node and dependencies.
  start-overmind = pkgs.writeTextFile {
    name = "start-overmind.sh";
    text = ''
      OVERMIND_CAN_DIE=reset overmind start -D -N /app/Procfile
    '';
    executable = true;
    destination = "/app/bin/start-overmind.sh";
  };
  # Overmind's configuration file.
  # The destination path is automatically created.
  procfile = pkgs.writeTextFile {
    name = "Procfile";
    text = ''
      ipfs: /app/bin/start-ipfs.sh
      lasr: sleep 5 && /app/bin/start-lasr.sh
    '';
    destination = "/app/Procfile";
  };
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
    jq
    kubo
    overmind
    tmux
  ] ++ [
    init-env
    start-pd-server
    start-tikv-server
    setup-working-dir
  ];

  # Enable docker socket
  virtualisation.docker.enable = true;
  users.users.root.extraGroups = [ "docker" ];
  # Automatically start the pd-server & tikv-server on server start
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      pd-server = {
        image = "pingcap/pd:latest";
        imageFile = pd-image;
        extraOptions = [
          "--network=host"
        ];
        cmd = [
          "--data-dir=/pd1"
          "--client-urls=http://0.0.0.0:2379"
          "--peer-urls=http://0.0.0.0:2380"
          "--advertise-client-urls=http://0.0.0.0:2379"
          "--advertise-peer-urls=http://0.0.0.0:2380"
        ];
      };
      tikv-server = {
        dependsOn = [ "pd-server" ];
        image = "pingcap/tikv:latest";
        imageFile = tikv-image;
        extraOptions = [
          "--network=host"
        ];
        cmd = [
          "--addr=127.0.0.1:20160"
          "--advertise-addr=127.0.0.1:20160"
          "--data-dir=/tikv"
          "--pd=http://127.0.0.1:2379"
        ];
      };
    };
  };

  # Before changing, read this first:
  # https://nixos.org/manual/nixos/stable/options.html#opt-system.stateVersion
  system.stateVersion = "24.04";
}
