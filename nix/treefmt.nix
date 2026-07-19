{inputs, ...}: {
  imports = [
    inputs.treefmt-nix.flakeModule
  ];

  perSystem = _: {
    # For nix fmt
    treefmt.config = {
      projectRootFile = "flake.nix";
      settings = {
        global.excludes = [
          "LICENSE"
          ".gitignore"
        ];
      };

      programs = {
        deadnix.enable = true;
        alejandra.enable = true;
        statix.enable = true;
        shellcheck.enable = true;
      };
    };
  };
}
