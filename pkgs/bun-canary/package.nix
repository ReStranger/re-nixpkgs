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
  writeShellScript,
  curl,
  jq,
  git,
}: let
  commit = "b284bbb97a42089f52de0e269c20a383f58c6b15";
  date = "20260720";
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "bun-canary";
    version = "consolidation-step-7-green";

    src =
      finalAttrs.passthru.sources.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}");

    sourceRoot =
      {
        aarch64-darwin = "bun-darwin-aarch64";
        x86_64-darwin = "bun-darwin-x64";
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
      ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [autoPatchelfHook];
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
          hash = "sha256-BxZ7G+GTts3ISsBxY1VFOWPQhmUWnHTomwK/zs9QWgI=";
        };
        "aarch64-linux" = fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/canary/bun-linux-aarch64.zip";
          hash = "sha256-d9GiVwDTRo+gMkmbg8d5d61Uypfo65Q93b6fhvyBhS0=";
        };
        "x86_64-darwin" = fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/canary/bun-darwin-x64.zip";
          hash = "sha256-wSMihcw3YHG5PpwKR7x94Etoe6oMPX7E2OitknqIgKA=";
        };
        "x86_64-linux" = fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/canary/bun-linux-x64.zip";
          hash = "sha256-qVNZHf+n1NsqGtYZOlMXC0rsqI+re9BO4KD3ItRqbVA=";
        };
      };
      inherit commit date;
      updateScript = writeShellScript "update-bun-canary" ''
        set -euo pipefail

        repo_root="$(git rev-parse --show-toplevel)"
        package_nix="$repo_root/pkgs/bun-canary/package.nix"

        commit=$(curl -fsSL "https://api.github.com/repos/oven-sh/bun/commits/main" | jq -r '.sha')
        date=$(curl -fsSL "https://api.github.com/repos/oven-sh/bun/commits/main" | jq -r '.commit.committer.date' | tr -d '-' | cut -c1-8)

        sed -i "s/^  commit = \"[a-f0-9]*\";$/  commit = \"$commit\";/" "$package_nix"
        sed -i "s/^  date = \"[0-9]*\";$/  date = \"$date\";/" "$package_nix"

        for asset in bun-darwin-aarch64.zip bun-linux-aarch64.zip bun-darwin-x64.zip bun-linux-x64.zip; do
          url="https://github.com/oven-sh/bun/releases/download/canary/$asset"
          hash=$(nix store prefetch-file --json --hash-type sha256 "$url" | jq -r '.hash')
          sed -i "/$asset/,/hash/{s|hash = \".*\"|hash = \"$hash\"|}" "$package_nix"
        done

        echo "Updated $package_nix"
        echo "commit=$commit"
        echo "date=$date"
      '';
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
      hydraPlatforms = lib.lists.remove "x86_64-darwin" lib.platforms.all;
    };
  })
