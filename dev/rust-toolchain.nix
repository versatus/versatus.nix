{ fenix, system, versatus }:
(fenix.packages.${system}.fromToolchainFile {
  file = versatus + "/rust-toolchain.toml";
  sha256 = "sha256-SXRtAuO4IqNOQq+nLbrsDFbVk+3aVA8NNpSZsKlVH/8=";
})
