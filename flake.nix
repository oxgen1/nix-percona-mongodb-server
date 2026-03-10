{
  description = "Percona Server for MongoDB 8.0 - Nix packaging (prebuilt binaries)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    {
      # packages = nixpkgs.lib.genAttrs systems (system: perconaPackagesFor system // {
      #   default = (perconaPackagesFor system).percona-server-mongodb;
      # });

      overlays.default = final: prev: {
        percona-server-mongodb = final.callPackage ./pkgs/percona-server-mongodb { };
        percona-mongosh = final.callPackage ./pkgs/mongosh { };
      };

      nixosModules.default =
        {
          pkgs,
          config,
          lib,
          ...
        }:
        {
          imports = [ ./modules/percona-server-mongodb.nix ];
              nixpkgs.config.allowUnfree = true;

          nixpkgs.overlays = [ self.overlays.default ];
        };

      nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.nixosModules.default
          (
            { pkgs, modulesPath, ... }:
            {
              imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];
              virtualisation.memorySize = 4096;
              virtualisation.cores = 4;
              virtualisation.graphics = false;
              virtualisation.forwardPorts = [
                {
                  from = "host";
                  host.port = 9001;
                  guest.port = 9001;
                }
              ];

              fileSystems."/" = {
                device = "/dev/disk/by-label/nixos";
                fsType = "ext4";
              };
              boot.loader.grub.device = "/dev/vda";

              services.percona-server-mongodb.enable = true;
              # Setup simple root password to debug inside the serial console if necessary
              users.users.root.password = "nixos";
              system.stateVersion = "24.05";
            }
          )
        ];
      };
    };

}
