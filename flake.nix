{
  description = "ghbak - per-owner daily GitHub org backups (mirrors + LFS + optional restic snapshots)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          ghbak = pkgs.writeShellApplication {
            name = "ghbak";
            text = builtins.readFile ./bin/ghbak;
            runtimeInputs = [
              pkgs.coreutils
              pkgs.git
              pkgs.git-lfs
              pkgs.gh
              pkgs.util-linux # flock
              pkgs.restic
            ];
          };

          default = self.packages.${system}.ghbak;
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.ghbak}/bin/ghbak";
        };
      });

      formatter = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in pkgs.nixfmt-rfc-style);
    };
}
