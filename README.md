# versatus.nix

A Nix flake for the Versatus Labs ecosystem which provides reproducible build guarantees for Versatus 
binaries, [development environments](#development-shells) for building Versatus repositories on [supported systems](#supported-systems)
and [NixOS images & infrastructure for deploying Versatus services](./deployments/README.md).

## Prerequisites

Nix is a package manager with a focus on reproducibility and reliability.
To get started, choose an installation type at https://nixos.org/download. MacOS users, please read on.

**For MacOS users**, the graphical installer made available by Determinate Systems has some advantages and is recommended over the official installer, which are explained and can be found here: https://determinate.systems/posts/graphical-nix-installer.
Additionally, MacOS users may want to enable the `nix-darwin` module features in order to run linux virtual machines locally, otherwise this step may be skipped.
The [deployment guide](./deployments/README.md#nixos-vm-darwin) has a detailed walkthrough with examples and trouble shooting for getting started with the `nix-darwin` `linux-builder` feature.

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

To enter a temporary [development shell](#development-shells) with `nix develop`:
```sh
nix develop .#<development-shell>
```

### Supported Systems

- x86_64-linux
- x86_64-darwin
- aarch64-linux
- aarch64-darwin
> Note: The Determinate Systems Nix installer also supports WSL.

### Development Shells

- `.#nix-dev` - tools necessary for building & maintaining the `versatus.nix` flake
- `.#protocol-dev` - tools necessary for building the Versatus protocol
- `.#lasr-dev` - tools necessary for building the Versatus LASR protocol
- `.#versa-rs` - Rust language tools for building the `versatus-rust` quickstart kit
- `.#versa-hs` - Haskell language tools for building the `versatus-haskell` quickstart kit 

> Note: Coming soon:
- `.#compute-dev` - tools necessary for building the Versatus compute stack (for now this is part of protocol-dev)
- `.#versa-py` - Python language tools for building the `versatus-python` quickstart kit
- `.#versa-js` - JavaScript language tools for building the `versatus-javascript` quickstart kit
- `.#versa-c` - C language tools for building the `versatus-c` quickstart kit
- `.#versa-cpp` - C++ language tools for building the `versatus-cpp` quickstart kit
- `.#versa-go` - Go language tools for building the `versatus-go` quickstart kit
