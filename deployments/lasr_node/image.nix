{ pkgs ? import <nixpkgs> {} }:
let
  config = {
    imports = [ <nixpkgs/nixos/modules/virtualisation/digital-ocean-image.nix> ];
  };
in
(pkgs.nixos config).digitalOceanImage.overrideAttrs (_: {
  imports = [ ./configuration.nix ];
})

