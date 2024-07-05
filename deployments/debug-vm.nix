
{ modulesPath, ... }: {
    imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];

    virtualisation = {
        cores = 3;
        # The virtual machine's system architecture
        # Ports are subject to change
        forwardPorts = [
            { from = "host"; host.port = 2222; guest.port = 22; }
        ];
        # Disk size & RAM may be increased as needed
        diskSize = 32768;
        memorySize = 4096;
        # The host's version of nixpkgs used to build the VM
    };

    users.users.root.hashedPassword = "";

    services.openssh = {
        enable = true;
        settings.PermitRootLogin = "yes";
        settings.PermitEmptyPasswords = "yes";
    };
    security.pam.services.sshd.allowNullPassword = true;

    nix.settings.experimental-features = ["nix-command" "flakes"];
}