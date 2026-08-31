# mr-boxington shares Cargo compilation results across worktrees and manages
# target directories. nixpkgs does not package it yet, so install the verified
# upstream release archives instead of compiling the Rust workspace locally.
final: _prev:
let
  version = "1.1.0";
  inherit (final.stdenv.hostPlatform) system;
  assets = {
    "x86_64-linux" = {
      # The GNU archive expects /lib64/ld-linux-x86-64.so.2. Use the static
      # musl archive so the binary also runs inside a Nix build sandbox.
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-n1kKD9D8CliWeRJXhjmA/pxgNUWEFFdXScxD5o5/8M8=";
    };
    "aarch64-darwin" = {
      target = "aarch64-apple-darwin";
      hash = "sha256-2pZmFTRID/817HjlmBJNIIrB8mJMbTwofJripYUrCyk=";
    };
  };
  asset = assets.${system} or (throw "mr-boxington: unsupported system ${system}");
in
{
  mr-boxington = final.stdenvNoCC.mkDerivation {
    pname = "mr-boxington";
    inherit version;

    src = final.fetchurl {
      url =
        "https://github.com/jdx/mr-boxington/releases/download/v${version}/"
        + "mbx-${asset.target}.tar.gz";
      inherit (asset) hash;
    };

    sourceRoot = ".";
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true; # Preserve the upstream macOS signature and the Linux binary verbatim.

    installPhase = ''
      runHook preInstall
      install -Dm755 mbx "$out/bin/mbx"
      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      "$out/bin/mbx" --version | grep -Fx "mbx ${version}"
    '';

    meta = with final.lib; {
      description = "Content-addressed Cargo cache and managed target directories";
      homepage = "https://mr-boxington.jdx.dev/";
      license = licenses.mit;
      mainProgram = "mbx";
      platforms = builtins.attrNames assets;
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
    };
  };
}
