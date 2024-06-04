{ pkgs ? import <nixpkgs> {} }:
let
  opts = import ./nightly-options.nix { inherit pkgs; };
  nixos_config = {
    imports = [ (pkgs.callPackage ../../digital-ocean/digital-ocean-image.nix { inherit opts; }) ];
  };
in
(pkgs.nixos nixos_config).digitalOceanImage
