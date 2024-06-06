{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/digital-ocean-config.nix")
    (modulesPath + "/virtualisation/digital-ocean-image.nix")
  ];
  virtualisation.digitalOceanImage.configFile = ./configuration.nix;
  boot.loader.grub.device = "/dev/vdb";
}
