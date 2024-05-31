{ lib, pkgs, ... }:
{
  disko.devices.disk.digitalocean = let
    boot = {
      priority = 0;
      size = "1M";
      type = "EF02";
    };
    ESP = {
      priority = 1;
      size = "100M";
      type = "EF00";
      content = {
        type = "filesystem";
        format = "vfat";
        mountpoint = "/boot";
      };
    };
    root = {
      priority = 3;
      size = "100%";
      content = {
        type = "filesystem";
        format = "ext4";
        mountpoint = "/";
      };
    };
  in
  {
    device = lib.mkDefault "/dev/vda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        boot = boot;
        ESP = ESP;
        root = root;
      };
    };
  };
}
      
