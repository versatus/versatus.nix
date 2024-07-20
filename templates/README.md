# Versatus Templates

Templates for creating new Versatus projects.

## Getting Started

Choose a template from the [available templates](#available-templates) below to initialize a new project.

```sh
# replace <available-template> with the template of your choosing.
nix flake init -t github:versatus/versatus.nix#<available-template>
```

## Available Templates

- `rust-package`: 
    Initializes a nix flake that includes the boilerplate code for building
    and developing Versatus' rust-based single-package projects. A workspace
    template is also available: `rust-workspace`.

- `rust-workspace`:
    Initializes a nix flake that includes the boilerplate code for building
    and developing Versatus' rust-based workspace projects. A single-package
    template is also available: `rust-package`.
