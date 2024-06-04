# The configuration.nix file located at `/etc/nixos/configuration.nix` used for rebuilding.
{ modulesPath, lib, opts, ... }:
{
  imports = lib.optional (builtins.pathExists ./do-userdata.nix) ./do-userdata.nix ++ [
    (modulesPath + "/virtualisation/digital-ocean-config.nix")
  ];

  networking.hostName = opts.networking.hostName;
  environment.systemPackages = opts.environment.systemPackages;
  users.users.root.openssh.authorizedKeys.keys = opts.users.users.root.openssh.authorizedKeys.keys;
}

