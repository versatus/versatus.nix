# Cross-platform rust-toolchain builds.
{
  makeRustPlatform,
  versatus,
  rust-toolchain,
  pkg-config,
  clang,
  libclang,
  rocksdb,
  openssl,
  libiconv,
  lib,
  stdenv,
  darwin
}:
(makeRustPlatform {
  cargo = rust-toolchain;
  rustc = rust-toolchain;
}).buildRustPackage
{
  pname = "protocol-dev";
  version = "0.0.0";
  src = versatus;
  cargoLock.lockFile = versatus + "/Cargo.lock";
  nativeBuildInputs = [
    pkg-config
    clang
  ];
  buildInputs = [
    rocksdb
    openssl.dev
    libiconv
  ] ++ lib.optionals stdenv.isDarwin [
    darwin.apple_sdk.frameworks.Security
    darwin.apple_sdk.frameworks.SystemConfiguration
  ];
  LIBCLANG_PATH = "${libclang.lib}/lib";
  ROCKSDB_LIB_DIR = "${rocksdb}/lib";
}
