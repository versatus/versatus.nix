{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/digital-ocean-config.nix")
    (modulesPath + "/virtualisation/digital-ocean-image.nix")
  ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  virtualisation.digitalOceanImage.configFile = ./configuration.nix;
  boot.loader.grub.device = "/dev/vdb";
}
