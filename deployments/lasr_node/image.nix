{ pkgs ? import <nixpkgs> {} }:
let
  config = {
    imports = [ <nixpkgs/nixos/modules/virtualisation/digital-ocean-image.nix> ];
    options.virtualisation.digitalOceanImage.configFile = import ./configuration.nix;
  };
in
(pkgs.nixos config).digitalOceanImage
