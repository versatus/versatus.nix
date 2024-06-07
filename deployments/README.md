# NixOS Deployments

## Deployment Processes

#### DigitalOcean Deployment Process

There are many ways to deploy NixOS images to server providers, but DigitalOcean is slightly more nuanced.
The server identity must be maintained between operating system updates, e.g. an Ubuntu 24.04 installation
cannot be converted to a NixOS 24.04 installation. This is not a problem for other server providers since
they don't rely on the OS as part of their API. That said here is how we are deploying to DigitalOcean
servers with NixOS:

1. NixOS images are created for each server
2. The images are uploaded to DigitalOcean via API, old images are deleted
3. The existing servers are rebuilt with the new images
4. A `systemd` startup script runs upon successful server start which deploys the `lasr_node`
5. This process continues automatically, pulling the most recent changes from the `lasr` repository on a nightly and bi-weekly basis

## Rebuilding The NixOS Server
**Be aware that changes to the server with these methods are semi-permanent at best. To add permanent changes please file
an issue and pull request that closes said issue.**

### Before Rebuilding...
Be aware that unless the packages need to be made available semi-permanently on the server,
using the `nix-shell` feature will open a shell with the packages added to `$PATH`
and is often the solution if a developer tool is needed only temporarily, or for testing means **while on the server**.
> For more commands please consult the manual: `nix-shell --help`.

```sh
ssh <user>@<ip-address>
# make packages available on the current $PATH (exiting the shell will remove them)
nix-shell -p <package-name1> <package-name2>
# or if just needing to run a program once
nix-shell --run "command arg1 arg2 ..."
```

In the case of needing to update the configuration on a development server where you may be testing new features, etc., 
there are two main ways to apply your changes, but both rely on the `nixos-rebuild switch` command with the option `--flake`.

The first instinct for seasoned NixOS users would be to edit, and rebuild as if it was a local system, however this ins't
the correct way to go about it when dealing with NixOS servers. I've tentatively made it to where attempting to do so will
produce an error:
> ERROR: Attempting to rebuild from a default configuration.

Which will then walk you through the process of applying your changes, which is as follows:

### Rebuild From Your Local Machine
This will be the most common way of adding **semi-permanent changes**, since it doesn't require the server
itself to be aware of the original configuration, i.e. the versatus.nix git repository.
Likely the changes that will often be made are to the packages included on the server,
and those packages should be added under `environment.systemPackages` in `deployments/<name-of-image>/common.nix`.
This command is especially helpful when needing to test changes that will eventually be applied permanently
to the server image documented in the [Deployment Processes](#deployment-processes).

To rebuild the configuration on a server please update your local copy of
the configuration you are trying to change in the nix flake, then target the server
you would like to rebuild with that configuration from your machine.

```sh
nixos-rebuild \
  --flake .#<name-of-configuration> \
  --build-host <user>@<ip-address> \
  --target-host <user>@<ip-address> \
  switch
```

Additionally, MacOS users must pass the `--fast` flag.
The build host and target host will be the same, and if the user is not `root`, you must
also pass it the `--use-remote-sudo` flag, assuming the user has sudo privileges.

### Rebuild From The Server
If rebuilding from the server itself, you must have a copy of the original flake used
to produce the system configuration you are on.

```sh
ssh <user>@<ip-address>
git clone <flake-repository>
```

Make your changes and be sure to add new files to git, otherwise the flake will not apply them.
Then rebuild from the flake:

```sh
git add -A
nixos-rebuild switch --flake .#<name-of-configuration>
```

## Troubleshooting

### Unable To Connect After Server Rebuild
After rebuilding the server with `nixos-rebuild`, or the server is rebuilt from a newer
version of the NixOS image, you may encounter an error when attempting to connect to the
server via SSH. Multiple attempts of this will prompt you with a warning of potential
"man-in-the-middle" attacks. To reset your relationship with the server navigate to your
`~/.ssh` folder, and remove the server's host keys from the `known_hosts` file. You should
be able to now connect to the server, which will prompt you to add the new keys to `~/.ssh/known_hosts`. 
