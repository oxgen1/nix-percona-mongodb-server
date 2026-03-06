{
  description = "Percona Server for MongoDB 8.0 - Nix packaging (prebuilt binaries)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        perconaPackages = {
          percona-server-mongodb = pkgs.callPackage ./pkgs/percona-server-mongodb { };
          mongosh = pkgs.callPackage ./pkgs/mongosh { };
        };
      in
      {
        packages = perconaPackages // {
          default = perconaPackages.percona-server-mongodb;
        };

        devShells.default = pkgs.mkShell {
          packages = [
            perconaPackages.percona-server-mongodb
            perconaPackages.mongosh
          ];
        };
      }
    ) // {
      nixosModules.percona-server-mongodb = import ./modules/percona-server-mongodb.nix;
      nixosModules.default = self.nixosModules.percona-server-mongodb;
    };
}
