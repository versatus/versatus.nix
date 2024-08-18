final: prev:
let
  mkRustToolchain = toml_path: hash: {
    fenix-pkgs = (final.fenix.fromToolchainFile {
      file = toml_path;
      sha256 = hash;
    });
    darwin-pkgs = (with pkgs; lib.optionals stdenv.isDarwin [
      # Additional darwin specific inputs
      libiconv
      darwin.apple_sdk.frameworks.Security
      darwin.apple_sdk.frameworks.SystemConfiguration
    ]);
    complete = [ fenix-pkgs darwin-pkgs ];
  };
in
{
  lib = prev.lib // {
    inherit mkRustToolchain;
  }; 
}
