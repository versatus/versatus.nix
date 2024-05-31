{ modulesPath, config, lib, pkgs, ... }: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    # https://github.com/NixOS/nixpkgs/blob/c5187508b11177ef4278edf19616f44f21cc8c69/nixos/modules/virtualisation/digital-ocean-config.nix
    (modulesPath + "/virtualisation/digital-ocean-config.nix")
  ];
  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.openssh.enable = true;

  networking = {
    hostName = "lasr-node-server";
    useDHCP = true;
    interfaces.eth0.useDHCP = true;
  };
  time.timeZone = "UTC";

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
  ];

  # Add your SSH key and comment your username/system-name
  users.users.root.openssh.authorizedKeys.keys = [
    # eureka-cpu
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINQ66bGgeELzU/wZjpYxSlKIgMoROQxPx76vGdpS3lwc github.eureka@gmail.com" # dev-one
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAsUzc7Wg9FwImAMPc61K/zO9gvUDJVHwQ0+GTrO1mqJ github.eureka@gmail.com" # critter-tank
  ];
  users.users.root = {
    password = "";
  };

  system.stateVersion = "23.11";
}
