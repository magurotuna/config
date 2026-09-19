# Herdr 0.9.0 can cancel mouse selections during terminal output (#3841).
# Use verified upstream binaries until nixpkgs provides 0.9.1 or newer.
# This avoids compiling Rust and libghostty locally for a temporary fix.
final: prev:
let
  version = "0.9.1";
  inherit (final.stdenv.hostPlatform) system;
  assets = {
    "x86_64-linux" = {
      # The upstream Linux release uses musl and is statically linked.
      name = "herdr-linux-x86_64";
      hash = "sha256-KgL+0WvrZR7wBuHUPwSPZSyk3FitBTzS1ERQVj1cVLc=";
    };
    "aarch64-darwin" = {
      name = "herdr-macos-aarch64";
      hash = "sha256-X8en5636ylb6gKqJ3LAlaTNXJo2rgoW5zi0IojE8id4=";
    };
  };
  asset = assets.${system} or (throw "herdr: unsupported system ${system}");
  canExecute = final.stdenv.buildPlatform.canExecute final.stdenv.hostPlatform;
in
{
  herdr =
    if final.lib.versionAtLeast prev.herdr.version version then prev.herdr
    else final.stdenvNoCC.mkDerivation {
      pname = "herdr";
      inherit version;

      src = final.fetchurl {
        url = "https://github.com/herdrdev/herdr/releases/download/v${version}/${asset.name}";
        inherit (asset) hash;
      };

      nativeBuildInputs = [ final.installShellFiles ];
      dontUnpack = true;
      dontConfigure = true;
      dontBuild = true;
      dontFixup = true; # Preserve the upstream macOS signature and static Linux binary.

      installPhase = ''
        runHook preInstall
        install -Dm755 "$src" "$out/bin/herdr"
        runHook postInstall
      '';

      # Retain the completions and skill data installed by the nixpkgs package.
      postInstall = final.lib.optionalString canExecute ''
        mkdir -p "$out/share/herdr/skills/herdr"
        "$out/bin/herdr" --skill > "$out/share/herdr/skills/herdr/SKILL.md"
        installShellCompletion --cmd herdr \
          --bash <("$out/bin/herdr" completion bash) \
          --fish <("$out/bin/herdr" completion fish) \
          --zsh <("$out/bin/herdr" completion zsh)
      '';

      doInstallCheck = canExecute;
      installCheckPhase = ''
        "$out/bin/herdr" --version | grep -Fx "herdr ${version}"
      '';

      meta = with final.lib; {
        description = "Agent multiplexer that lives in your terminal";
        homepage = "https://herdr.dev";
        changelog = "https://github.com/herdrdev/herdr/releases/tag/v${version}";
        license = licenses.asl20;
        mainProgram = "herdr";
        platforms = builtins.attrNames assets;
        sourceProvenance = [ sourceTypes.binaryNativeCode ];
      };
    };
}
