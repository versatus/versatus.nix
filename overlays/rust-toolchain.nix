final: prev:
let
  mkRustToolchain = toml_path: hash:
    let
      fenix-pkgs = (final.fenix.fromToolchainFile {
        file = toml_path;
        sha256 = hash;
      });
      darwin-pkgs = (with final; lib.optionals stdenv.isDarwin [
        # Additional darwin specific inputs
        libiconv
        darwin.apple_sdk.frameworks.Security
        darwin.apple_sdk.frameworks.SystemConfiguration
      ]);
    in
    {
      inherit fenix-pkgs darwin-pkgs;
      complete = [ fenix-pkgs darwin-pkgs ];
    };
in
{
  lib = prev.lib // {
    inherit mkRustToolchain;
  };
}
