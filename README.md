# versatus.nix

A Nix flake for the Versatus Labs ecosystem which provides reproducible build guarantees for Versatus 
binaries, [development environments](#development-shells) for building Versatus repositories on [supported systems](#supported-systems)
and [NixOS images & infrastructure for deploying Versatus services](./nixos/modules/deployments/README.md).

This flake is the core infrastructure for Versatus repositories. It contains a `lib` attribute with
functions for crafting toolchains, modules and virtualisation tools for creating NixOS configurations
and local virtual environments, templates, with robust tooling, for managing projects, and more.

## Prerequisites

Nix is a package manager with a focus on reproducibility and reliability.
To get started, choose an installation type at https://nixos.org/download. MacOS users, please read on.

**For MacOS users**, the graphical installer made available by Determinate Systems has some advantages and is recommended over the official installer, which are explained and can be found here: https://determinate.systems/posts/graphical-nix-installer.

Additionally, MacOS users may want to enable the `nix-darwin` module features in order to run linux virtual machines locally, otherwise this step may be skipped.
The [deployment guide](./nixos/modules/deployments/README.md#nixos-vm-darwin) has a detailed walkthrough with examples and trouble shooting for getting started with the `nix-darwin` `linux-builder` feature.

### Nixpkgs

For the Nix package manager on non-NixOS distributions, add the following to `/etc/nix/nix.conf`:
> Note: If you used the Determinate Systems Nix installer, these settings are enabled by default.
```
experimental-features = nix-command flakes
```

### NixOS

For the Nix operating system, add the following to `/etc/nixos/configuration.nix`:
```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

## Developer Quick Start

First, ensure your system is listed under [Supported Systems](#supported-systems).

Then enter a temporary development shell with `nix develop`:
```sh
nix develop
```

### Supported Systems

- x86_64-linux
- x86_64-darwin
- aarch64-linux
- aarch64-darwin
> Note: The Determinate Systems Nix installer also supports WSL.

### Available Toolchain Functions

- `mkRustToolchainFromTOML`: 
    Given the path to a `rust-toolchain.toml`, produces the derivation
    for that toolchain for linux and darwin systems.
    Useful for rust projects that declare a `rust-toolchain.toml`.
- `mkHaskellToolchain`:
    Takes nixpkgs as input, provides common haskell tools and automatically
    resolves paths. Includes LD_LIBRARY_PATH environment variable.

> Note: The following functions will be created as time allows.
> If a toolchain you would like to see isn't present please feel free to file an issue
> and follow it up with a Pull Request.

- `mkJsToolchain`
- `mkGoToolchain`
- `mkPythonToolchain`
- `mkClangToolchain`
- `mkCppToolchain`
