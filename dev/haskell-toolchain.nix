{ pkgs, ... }:
let
  # Wrap Stack to work with our Nix integration. We don't want to modify
  # stack.yaml so non-Nix users don't notice anything.
  # --no-nix:         We don't want Stack's way of integrating Nix.
  # --system-ghc:     Use the existing GHC on PATH (will come from this Nix file)
  # --no-install-ghc: Don't try to install GHC if no matching GHC found on PATH
  stackWrapped = pkgs.symlinkJoin {
    name = "stack"; # will be available as the usual `stack` in terminal
    paths = [ pkgs.stack ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/stack \
        --add-flags "\
          --no-nix \
          --system-ghc \
          --no-install-ghc \
        "
    '';
  };
  # Uses the latest compatible nixpkgs version.
  # Updating nixpkgs with `nix flake update` may break this.
  hs-pkgs = pkgs.haskell.packages.ghc963;
in
[ stackWrapped ] ++ (with hs-pkgs; [
  ghc
  ghcid
  cabal-install
  ormolu
  hlint
  hoogle
  haskell-language-server
  implicit-hie
  retrie
  zlib
])

