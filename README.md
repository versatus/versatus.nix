# versatus.nix

A Nix flake for the Versatus Labs ecosystem which provides reproducible build guarantees for Versatus 
binaries, [development environments](#development-shells) for building Versatus repositories on [supported systems](#supported-systems)
and [NixOS images & infrastructure for deploying Versatus services](./deployments/README.md).

## Prerequisites

Nix is a package manager with a focus on reproducibility and reliability.
To get started, choose an installation type at https://nixos.org/download.

### Nixpkgs

For the Nix package manager on non-NixOS distributions, add the following to `/etc/nix/nix.conf`:
```
experimental-features = nix-command flakes
```

### NixOS

For the Nix operating system, add the following to `/etc/nixos/configuration.nix`:
```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

## Quick Start

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
