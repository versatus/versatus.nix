{ modulesPath, opts, ... }:
{
  imports = [ (modulesPath + "/virtualisation/digital-ocean-config.nix") ];

  networking.hostName = opts.networking.hostName;
  environment.systemPackages = opts.environment.systemPackages;
  users.users.root.openssh.authorizedKeys.keys = opts.users.users.root.openssh.authorizedKeys.keys;
}
