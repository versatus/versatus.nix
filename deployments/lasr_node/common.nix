{ pkgs, ... }:
let
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
  # Starts the TiKV server.
  start-tikv-server = pkgs.writeShellScriptBin "start-tikv-server.sh" ''
    docker run -d --name tikv-server --network host pingcap/tikv:latest \
        --addr="127.0.0.1:20160" \
        --advertise-addr="127.0.0.1:20160" \
        --data-dir="/tikv" \
        --pd="http://127.0.0.1:2379"
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

  # Starts the lasr_node from the release build.
  start-lasr = pkgs.writeTextFile {
    name = "start-lasr.sh";
    text = ''
      PREFIX=/app/lasr
      cd $PREFIX

      # TODO: Figure out a way to pass the secret key securely.
      # SECRET_KEY= \
      BLOCKS_PROCESSED_PATH="/app/blocks_processed.dat" \
      ETH_RPC_URL="https://u0anlnjcq5:xPYLI9OMwxRqJZqhfgEiKMeGdpVjGduGKmMCNBsu46Y@u0auvfalma-u0j1mdxq0w-rpc.us0-aws.kaleido.io/" \
      EO_CONTRACT_ADDRESS=0x563f0efeea703237b32ae7f66123b864f3e46a3c \
      COMPUTE_RPC_URL=ws://localhost:9125 \
      STORAGE_RPC_URL=ws://localhost:9126 \
      BATCH_INTERVAL=180 \
      	/app/lasr/target/release/lasr_node
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
    kubo
    overmind
    tmux
  ] ++ [
    start-pd-server
    start-tikv-server
    start-ipfs
    start-lasr
    start-overmind
    procfile
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
