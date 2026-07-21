{pkgs, ...}: {
  perSystem = _: {
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [
        nix-update
        nurl
        nix-prefetch-github
        jq
        cachix
      ];
    };
  };
}
