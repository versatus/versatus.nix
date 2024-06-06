# The configuration.nix file located at `/etc/nixos/configuration.nix` on the server, usually used for rebuilding.
# Here we throw an error if a user attempts to rebuild from the server machine using `nixos-rebuild switch`.
{ ... }:
throw ''
  ERROR: Attempting to rebuild from a default configuration. Unfortunately this is not
  the idiomatic approach to rebuilding with changes on the server.

  To rebuild the configuration on a server please update your local copy of
  the configuration you are trying to change in the nix flake, then target the server
  you would like to rebuild with that configuration from your machine.

  $ nixos-rebuild \
      --flake .#<name-of-configuration> \
      --build-host <user>@<ip-address> \
      --target-host <user>@<ip-address> \
      switch

  Additionally, MacOS users must pass the --fast flag.
  The build host and target host will be the same, and if the user is not root, you must
  also pass it the --use-remote-sudo flag, assuming the user has sudo privileges.

  If rebuilding from the server itself, you must have a copy of the original flake used
  to produce the system configuration you are on.

  $ ssh <user>@<ip-address>
  $ git clone <flake-repository>

  Make your changes and be sure to add new files to git, otherwise the flake will not apply them.
  Then rebuild from the flake:

  $ git add -A
  $ nixos-rebuild switch --flake .#<name-of-configuration>
''

