final: prev:

let
  craneLib = prev.craneLib;

  lasr = prev.lasrSrc;
  lasrSrc = craneLib.cleanCargoSource (craneLib.path (builtins.toString lasr));

  lasrArgs = {
    pname = "lasr_node";
    version = "1";
    src = lasrSrc;
    strictDeps = true;
    nativeBuildInputs = [ final.pkg-config ];
    buildInputs = [ final.openssl.dev final.rustToolchain.darwin-pkgs ];
  };

  # Build *just* the cargo dependencies, so we can reuse
  # all of that work (e.g. via cachix) when running in CI
  lasrDeps = craneLib.buildDepsOnly lasrArgs;
in
{

  lasr_node = craneLib.buildPackage (lasrArgs // {
    pname = "lasr_node";
    version = "1";
    doCheck = false;
    cargoArtifacts = lasrDeps;
    cargoExtraArgs = "--locked --bin lasr_node";
  });
  lasr_cli = craneLib.buildPackage (lasrArgs // {
    pname = "lasr_cli";
    version = "1";
    doCheck = false;
    cargoArtifacts = lasrDeps;
    cargoExtraArgs = "--locked --bin lasr_cli";
  });
}
