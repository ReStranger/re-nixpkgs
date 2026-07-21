{
  description = "A small personal package collection";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  nixConfig = {
    extra-substituters = [ "https://re-nixpkgs.cachix.org" ];
    extra-trusted-public-keys = [
      "re-nixpkgs.cachix.org-1:yp0DeOCu+yrfJ3u3Ih9JopChk1MCKbkFvH2gMmzrOdw="
    ];
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
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
      perSystem = {pkgs, ...}: {
        packages = pkgs.lib.filesystem.packagesFromDirectoryRecursive {
          inherit (pkgs) callPackage;
          directory = ./pkgs;
        };
      };
      flake = {
        overlays.default = final: _prev:
          final.lib.filesystem.packagesFromDirectoryRecursive {
            inherit (final) callPackage;
            directory = ./pkgs;
          };
      };
    };
}
