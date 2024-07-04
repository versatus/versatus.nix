{ pkgs, lasr_pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  # Pull the PD server image from dockerhub
  pd-image = let
    platformSha256 = {
      "aarch64-linux" = "sha256-+IBB5p1M8g3fLjHbF90vSSAoKUidl5cdkpTulkzlMAc=";
      "x86_64-linux" = "sha256-xNPJrv8y6vjAPNvn9lAkghCfRGUDiBfRCUBsEYvb49Q=";
    }."${system}" or (builtins.throw "Unsupported platform, must either be arm64 or amd64 Linux: found ${system}");
  in
  pkgs.dockerTools.pullImage {
    imageName = "pingcap/pd";
    imageDigest = "sha256:0e87d077d0fd92903e26a6ebeda633d6979380aac6fc76aa24c6a02d25a404f6";
    sha256 = platformSha256;
    finalImageTag = "latest";
    finalImageName = "pingcap/pd";
  };
  # Starts the placement driver server for TiKV.
  # NOTE: This is a global script, which is run by default and is only
  # necessary in scenarios where the server does not start automatically.
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
    platformSha256 = {
      "aarch64-linux" = "sha256-JbogHq9FLfm7x08xkwiDF0+YyUKRXF34vHty+ZxIZh0=";
      "x86_64-linux" = "sha256-udLF3mAuUU08QX2Tg/mma9uu0JdtdJuxK3R1bqdKjKk=";
    }.${system} or (builtins.throw "Unsupported platform, must either be arm64 or amd64 Linux: found ${system}");
  in
  pkgs.dockerTools.pullImage {
    imageName = "pingcap/tikv";
    imageDigest = "sha256:e68889611930cc054acae5a46bee862c4078af246313b414c1e6c4671dceca63";
    sha256 = platformSha256;
    finalImageTag = "latest";
    finalImageName = "pingcap/tikv";
  };
  # Starts the TiKV server.
  # NOTE: This is a global script, which is run by default and is only
  # necessary in scenarios where the server does not start automatically.
  start-tikv-server = pkgs.writeShellScriptBin "start-tikv-server.sh" ''
    docker run -d --name tikv-server --network host pingcap/tikv:latest \
        --addr="127.0.0.1:20160" \
        --advertise-addr="127.0.0.1:20160" \
        --data-dir="/tikv" \
        --pd="http://127.0.0.1:2379"
  '';

  # Creates the working directory, scripts & initializes the IPFS node.
  # NOTE: This is a global script, which is run by default and is only
  # necessary in scenarios where the systemd service fails.
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
  # NOTE: This is a global script, which is run by default and is only
  # necessary in scenarios where the systemd service fails.
  init-env = pkgs.writeShellScriptBin "init-env.sh" ''
    if [ -e "\$HOME/.bashrc" ]; then
      echo "Environment already initialized."
      exit 0
    fi

    secret_key=$(lasr_cli wallet new | jq '.secret_key')
    block_path="/app/blocks_processed.dat"
    eth_rpc_url="https://u0anlnjcq5:xPYLI9OMwxRqJZqhfgEiKMeGdpVjGduGKmMCNBsu46Y@u0auvfalma-u0j1mdxq0w-rpc.us0-aws.kaleido.io/" 
    eo_contract=0x563f0efeea703237b32ae7f66123b864f3e46a3c
    compute_rpc_url=ws://localhost:9125 
    storage_rpc_url=ws://localhost:9126
    batch_interval=180
    echo "set -o noclobber" > ~/.bashrc
    echo "export SECRET_KEY=$secret_key" >> ~/.bashrc
    echo "export BLOCKS_PROCESSED_PATH=$block_path" >> ~/.bashrc
    echo "export ETH_RPC_URL=$eth_rpc_url" >> ~/.bashrc
    echo "export EO_CONTRACT_ADDRESS=$eo_contract" >> ~/.bashrc
    echo "export COMPUTE_RPC_URL=$compute_rpc_url" >> ~/.bashrc
    echo "export STORAGE_RPC_URL=$storage_rpc_url" >> ~/.bashrc
    echo "export BATCH_INTERVAL=$batch_interval" >> ~/.bashrc
    echo "[[ \$- == *i* && -f \"\$HOME/.bashrc\" ]] && source \"\$HOME/.bashrc\"" > ~/.bash_profile

    source ~/.bashrc
    echo "Done"
    exit 0
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
  # Starts the lasr_node from the release build specified by the nix flake.
  start-lasr = pkgs.writeTextFile {
    name = "start-lasr.sh";
    text = ''
      PREFIX=/app/lasr
      cd $PREFIX

      # For local development:
      # The default behaviour will use the binary specified by the nix flake.
      # This is important because it retains the flake.lock versioning.
      # If this is not important to you, exchange the call to lasr_node
      # with the following:
      # ./target/release/lasr_node
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
    procfile
    setup-working-dir
    start-ipfs
    start-lasr
    start-overmind
    start-pd-server
    start-tikv-server
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

  # Node services that will run on server start
  systemd.user.services = {
    init-env = {
      description = "Initializes lasr_node environment variables and persists them between system boots.";
      script = ''
        if [ -f "\$HOME/.bashrc" ]; then
          echo "Environment already initialized."
          exit 0
        fi

        secret_key=$(${lasr_pkgs.lasr_cli}/bin/lasr_cli wallet new | ${pkgs.jq}/bin/jq '.secret_key')
        block_path="/app/blocks_processed.dat"
        eth_rpc_url="https://u0anlnjcq5:xPYLI9OMwxRqJZqhfgEiKMeGdpVjGduGKmMCNBsu46Y@u0auvfalma-u0j1mdxq0w-rpc.us0-aws.kaleido.io/" 
        eo_contract=0x563f0efeea703237b32ae7f66123b864f3e46a3c
        compute_rpc_url=ws://localhost:9125 
        storage_rpc_url=ws://localhost:9126
        batch_interval=180
        ipfs_path="/app/tmp/kubo"
        echo "set -o noclobber" > ~/.bashrc
        echo "export SECRET_KEY=$secret_key" >> ~/.bashrc
        echo "export BLOCKS_PROCESSED_PATH=$block_path" >> ~/.bashrc
        echo "export ETH_RPC_URL=$eth_rpc_url" >> ~/.bashrc
        echo "export EO_CONTRACT_ADDRESS=$eo_contract" >> ~/.bashrc
        echo "export COMPUTE_RPC_URL=$compute_rpc_url" >> ~/.bashrc
        echo "export STORAGE_RPC_URL=$storage_rpc_url" >> ~/.bashrc
        echo "export BATCH_INTERVAL=$batch_interval" >> ~/.bashrc
        echo "export IPFS_PATH=$ipfs_path" >> ~/.bashrc
        echo "[[ \$- == *i* && -f \"\$HOME/.bashrc\" ]] && source \"\$HOME/.bashrc\"" > ~/.bash_profile
        echo "Successfully initialized lasr_node environment."
      '';
      wantedBy = [ "default.target" ];
    };
    ipfs-start = {
      description = "Setup and start IPFS daemon.";
      preStart = ''
        if [ ! -e "/app/tmp/kubo" ]; then
          mkdir -p /app/tmp/kubo
          cd /app/tmp/kubo
          export IPFS_PATH=/app/tmp/kubo
          "${pkgs.kubo}/bin/ipfs" init
          echo "Initialized IPFS."
        else
          echo "IPFS already initialized."
        fi
      '';
      script = ''
        sleep 2
        IPFS_PATH=/app/tmp/kubo "${pkgs.kubo}/bin/ipfs" daemon
      '';
      wantedBy = [ "node-start.service" ];
    };
    node-start = {
      description = "Start the lasr_node process.";
      after = [ "init-env.service" "ipfs-start.service" ];
      preStart = ''
        if [ ! -e "/app/bin" ]; then
          echo "Setting up working directory.."
          mkdir -p /app/bin

          cd /app
          printf "${procfile.text}" > "${procfile.name}"
          "${pkgs.git}"/bin/git clone https://github.com/versatus/lasr.git

          cd /app/bin
          printf "${start-ipfs.text}" > "${start-ipfs.name}"
          printf "${start-lasr.text}" > "${start-lasr.name}"
          printf "${start-overmind.text}" > "${start-overmind.name}"

          for file in ./*; do
            chmod +x "$file"
          done

          echo "Working directory '/app' is ready."
        else
          echo "Working directory already exists."
        fi
      '';
      script = ''
        source "$HOME/.bashrc"
        "${lasr_pkgs.lasr_node}/bin/lasr_node"
      '';
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Restart = "always";
        RestartSec = 5;
      };
    };
  };

  # Before changing, read this first:
  # https://nixos.org/manual/nixos/stable/options.html#opt-system.stateVersion
  system.stateVersion = "24.04";
}
