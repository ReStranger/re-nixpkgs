{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  unzip,
  installShellFiles,
  makeWrapper,
  openssl,
  cctools,
  darwin,
  rcodesign,
}: let
  commit = "602db999be60abbf4876a6d4e6b98d6df70a2265";
  date = "20260721";
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "bun-canary";
    version = "canary-${builtins.substring 0 7 commit}";

    src =
      finalAttrs.passthru.sources.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}");

    sourceRoot =
      {
        aarch64-darwin = "bun-darwin-aarch64";
        aarch64-linux  = "bun-linux-aarch64";
        x86_64-linux   = "bun-linux-x64";
      }
      .${
        stdenvNoCC.hostPlatform.system
      } or null;

    strictDeps = true;
    nativeBuildInputs =
      [
        unzip
        installShellFiles
        makeWrapper
      ]
      ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [autoPatchelfHook]
      ++ lib.optionals stdenvNoCC.hostPlatform.isDarwin [cctools rcodesign];
    buildInputs = [openssl];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      install -Dm 755 ./bun $out/bin/bun
      ln -s $out/bin/bun $out/bin/bunx

      runHook postInstall
    '';

    postPhases = ["postPatchelf"];
    postPatchelf =
      lib.optionalString stdenvNoCC.hostPlatform.isDarwin ''
        '${lib.getExe' cctools "${cctools.targetPrefix}install_name_tool"}' $out/bin/bun \
          -change /usr/lib/libicucore.A.dylib '${lib.getLib darwin.ICU}/lib/libicucore.A.dylib'
        '${lib.getExe rcodesign}' sign --code-signature-flags linker-signed $out/bin/bun
      ''
      + lib.optionalString
      (
        stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform
        && !(stdenvNoCC.hostPlatform.isDarwin && stdenvNoCC.hostPlatform.isx86_64)
      )
      ''
        installShellCompletion --cmd bun \
          --bash <(SHELL="bash" $out/bin/bun completions) \
          --zsh <(SHELL="zsh" $out/bin/bun completions) \
          --fish <(SHELL="fish" $out/bin/bun completions)
      '';

    passthru = {
      sources = {
        "aarch64-darwin" = fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/canary/bun-darwin-aarch64.zip";
          hash = "sha256-p8CC9Ua0031l0D0xXezJ9oQJiw+aJIntiS+h+uFTJ+I=";
        };
        "aarch64-linux" = fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/canary/bun-linux-aarch64.zip";
          hash = "sha256-n+Xnv5PzG/Uiyc+GorClag8cLJLQndOHfgvcwg1lgmk=";
        };
        "x86_64-linux" = fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/canary/bun-linux-x64.zip";
          hash = "sha256-n4woKn3CxqYGhGj8CXVEh/nw8F6DS+C3m8y90dDOSKg=";
        };
      };
      inherit commit date;
      updateScript = ./update.sh;
    };

    meta = {
      homepage = "https://bun.sh";
      changelog = "https://github.com/oven-sh/bun/commits/${commit}";
      description = "Canary build of Bun - incredibly fast JavaScript runtime, bundler, transpiler and package manager, all in one";
      longDescription = ''
        Prebuilt canary binary of Bun, updated on every commit to main.
        Pinned at commit ${commit}.
      '';
      license = with lib.licenses; [
        mit
        lgpl21Only
      ];
      mainProgram = "bun";
      maintainers = with lib.maintainers; [ReStranger];
      platforms = builtins.attrNames finalAttrs.passthru.sources;
      broken = stdenvNoCC.hostPlatform.isMusl;
      hydraPlatforms = lib.platforms.linux ++ lib.platforms.darwin;
    };
  })
