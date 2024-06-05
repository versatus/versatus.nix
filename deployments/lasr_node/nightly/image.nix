{ pkgs ? import <nixpkgs> {} }:
let
  nightly_options = import ./nightly-options.nix { inherit pkgs; };
  nixos_config = {
    imports = [ <nixpkgs/nixos/modules/virtualisation/digital-ocean-image.nix> ];
    virtualisation.digitalOceanImage.configFile = ../../digital-ocean/config-file.nix;
  } // nightly_options;
in
(pkgs.nixos nixos_config).digitalOceanImage
