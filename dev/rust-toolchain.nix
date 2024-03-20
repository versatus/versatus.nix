{ lib, pkgs, fenix, system, versatus }:
let
  fenix-pkgs = (fenix.packages.${system}.fromToolchainFile {
    file = versatus + "/rust-toolchain.toml";
    sha256 = "sha256-SXRtAuO4IqNOQq+nLbrsDFbVk+3aVA8NNpSZsKlVH/8=";
  });
  darwin-pkgs = (with pkgs; lib.optionals stdenv.isDarwin [
    # Additional darwin specific inputs
    libiconv
    darwin.apple_sdk.frameworks.Security
    darwin.apple_sdk.frameworks.SystemConfiguration
  ]);
in
{
  fenix-pkgs = fenix-pkgs;
  darwin-pkgs = darwin-pkgs;
  complete = [ fenix-pkgs darwin-pkgs ];
}
