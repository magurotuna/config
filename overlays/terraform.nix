# terraform — unfree (BSL), so cache.nixos.org has no binary and nixpkgs
# compiles it from source on every machine. Use HashiCorp's official release
# binary instead.
#
# Updating: bump `version` and the four hashes by hand. Verify the upstream
# checksums file against HashiCorp's GPG key, then convert each hex digest:
#   v=<version>
#   curl -sSO https://releases.hashicorp.com/terraform/$v/terraform_${v}_SHA256SUMS
#   curl -sSO https://releases.hashicorp.com/terraform/$v/terraform_${v}_SHA256SUMS.sig
#   gpg --verify terraform_${v}_SHA256SUMS.sig terraform_${v}_SHA256SUMS
#   nix hash convert --hash-algo sha256 --to sri <hex digest>
final: prev:
let
  version = "1.16.6";
  platforms = {
    aarch64-darwin = { arch = "darwin_arm64"; hash = "sha256-heG8eKtFvcX4KnusOSnjfQcoNKWE0iWDokmNxnu2JM0="; };
    x86_64-darwin = { arch = "darwin_amd64"; hash = "sha256-eUo2w/fr9sWPIInCJgaKU50XBbo1ilZ5tRZxyNx+vHs="; };
    x86_64-linux = { arch = "linux_amd64"; hash = "sha256-OANLONAwljmaehJkoUVhqAKbK0lv0fFpRSZW5Tlo8bc="; };
    aarch64-linux = { arch = "linux_arm64"; hash = "sha256-p1C1oRA48WWEayZYxAyIzXBwqmemG6tDGhS6J5KOqeo="; };
  };
  platform = platforms.${final.stdenv.hostPlatform.system}
    or (throw "terraform overlay: unsupported system ${final.stdenv.hostPlatform.system}");
in
{
  terraform = final.stdenv.mkDerivation {
    pname = "terraform";
    inherit version;

    src = final.fetchurl {
      url = "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_${platform.arch}.zip";
      inherit (platform) hash;
    };

    nativeBuildInputs = [ final.unzip ];
    sourceRoot = ".";

    # Ship the upstream binary byte-for-byte: no strip / patchelf / re-sign.
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 terraform $out/bin/terraform
      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      $out/bin/terraform version
    '';

    meta = with final.lib; {
      description = "Infrastructure as code tool (official prebuilt release binary)";
      homepage = "https://www.terraform.io/";
      license = licenses.bsl11;
      mainProgram = "terraform";
      platforms = builtins.attrNames platforms;
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
    };
  };
}
