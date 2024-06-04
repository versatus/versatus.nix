{ pkgs ? import <nixpkgs> {} }:
let
  opts = import ./nightly-options.nix { inherit pkgs; };
  nixos_config = {
    imports = [ ../../digital-ocean/digital-ocean-image.nix { inherit opts; } ];
  };
in
(pkgs.nixos nixos_config).digitalOceanImage
