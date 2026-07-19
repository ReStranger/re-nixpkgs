{
  description = "A small personal package collection";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = let
        nixModules =
          builtins.filter
          (f: builtins.match ".*\.nix" f != null)
          (builtins.attrNames (builtins.readDir ./nix));
      in
        map (f: ./nix/${f}) nixModules;
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];
      perSystem = {pkgs, ...}: {
        packages = pkgs.lib.filesystem.packagesFromDirectoryRecursive {
          inherit (pkgs) callPackage;
          directory = ./pkgs;
        };
      };
      flake = {
        overlays.default = final: prev:
          final.lib.filesystem.packagesFromDirectoryRecursive {
            inherit (final) callPackage;
            directory = ./pkgs;
          };
      };
    };
}
