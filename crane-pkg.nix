{
  lib,
  craneLib,
  versatus,
  openssl,
  pkg-config,
  rocksdb,
  llvmPackages,
  clang
}:

craneLib.buildPackage {
  pname = "versatus";
  src = craneLib.cleanCargoSource (craneLib.path (builtins.toString versatus));
  strictDeps = true;
  nativeBuildInputs = [
    pkg-config
  ];
  buildInputs = [
    openssl.dev
    rocksdb
    clang
  ];
  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
  BINDGEN_EXTRA_CLANG_ARGS = "-isystem ${llvmPackages.libclang.lib}/lib/clang/${lib.getVersion clang}/include";
  ROCKSDB_LIB_DIR = "${rocksdb}/lib";
}
