{ pkgs ? import <nixpkgs> {} }:
let
  # opts = import ./nightly-options.nix { inherit pkgs; };
  nixos_config = {
    imports = [ <nixpkgs/nixos/modules/virtualisation/digital-ocean-image.nix> ];
    options.virtualisation.digitalOceanImage.configFile = ../../digital-ocean/config-file.nix;
  };
in
(pkgs.nixos nixos_config).digitalOceanImage
