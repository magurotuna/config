# clickhouse — on aarch64-darwin nixpkgs has no binary cache, so `pkgs.clickhouse`
# compiles from source (~1-2h, one of the heaviest C++ builds in nixpkgs) on every
# closure change. On the Mac we only want the client CLI (the server runs in
# Docker), and clickhouse is a single monolithic binary, so we wrap ClickHouse's
# official prebuilt macOS release binary instead of building.
#
# On Linux, clickhouse comes from the pinned `nixpkgs-clickhouse` input: at newer
# nixpkgs its final link fails (undefined Rust symbols in lib_ch_rust_prql.a), so
# Hydra has no cached build and a local build burns ~2h before failing. Drop the
# pin once https://hydra.nixos.org/job/nixos/unstable/nixpkgs.clickhouse.x86_64-linux
# shows Succeeded again.
#
# Updating: bump `version` + `hash` by hand (no surprise recompiles on flake
# update). Get the hash with:
#   nix store prefetch-file --hash-type sha256 \
#     https://github.com/ClickHouse/ClickHouse/releases/download/v<version>/clickhouse-macos-aarch64
#
# Two non-obvious gotchas (see inline comments below):
#  - The release binary is a self-extracting executable (~861KB Mach-O decompressor
#    stub + ~169MB appended compressed payload). Running codesign /
#    autoSignDarwinBinariesHook over the *compressed* binary rewrites the Mach-O
#    and drops the appended payload, leaving a useless stub. Never sign it.
#  - It self-decompresses (~735MB stripped) into its own directory on first run,
#    which fails in the read-only /nix/store ("mkstemp: Permission denied"). So we
#    decompress at BUILD time in the writable build dir, then install the result.
#    The extracted binary is ad-hoc + linker-signed, so it runs on Apple Silicon.
{ nixpkgs-clickhouse }:
final: prev:
let
  inherit (final.stdenv.hostPlatform) system;
in
{
  clickhouse =
    if system != "aarch64-darwin" then nixpkgs-clickhouse.legacyPackages.${system}.clickhouse
    else
      final.stdenv.mkDerivation rec {
        pname = "clickhouse";
        version = "26.6.1.1193-stable";

        src = final.fetchurl {
          url = "https://github.com/ClickHouse/ClickHouse/releases/download/v${version}/clickhouse-macos-aarch64";
          hash = "sha256-30SsuPH1K4z6n9Qb0Y4H4DmCxPf1ho/KEEPOObLo184=";
        };

        dontUnpack = true; # src is a single self-extracting binary, not an archive

        buildPhase = ''
          runHook preBuild
          cp $src clickhouse
          chmod 755 clickhouse
          # Self-decompress in place (170MB -> ~914MB). The trailing re-exec may
          # exit nonzero under the build sandbox, but the file is already replaced
          # by then, so ignore its status.
          ./clickhouse local --version || true
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 clickhouse $out/bin/clickhouse
          ln -s clickhouse $out/bin/clickhouse-client
          ln -s clickhouse $out/bin/clickhouse-local
          runHook postInstall
        '';

        # Prove the installed binary runs from the read-only store (catches a
        # botched decompression / accidental re-sign that strips the payload).
        doInstallCheck = true;
        installCheckPhase = ''
          $out/bin/clickhouse local --version
        '';

        meta = with final.lib; {
          description = "Column-oriented database management system (prebuilt macOS client binary)";
          homepage = "https://clickhouse.com/";
          license = licenses.asl20;
          mainProgram = "clickhouse";
          platforms = [ "aarch64-darwin" ];
          sourceProvenance = [ sourceTypes.binaryNativeCode ];
        };
      };
}
