{
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  llvmPackages,
  ffmpeg_7,
  sqlite,
  writeShellApplication,
  coreutils,
}:

let
  blissify-unwrapped = rustPlatform.buildRustPackage rec {
    pname = "blissify";
    version = "0.6.1";

    src = fetchFromGitHub {
      owner = "Polochon-street";
      repo = "blissify-rs";
      rev = "v${version}";
      hash = "sha256-C0f9JNILTbwA71VSLVS8mtWXoOAbBbMDcnNQwHaKKvg=";
    };

    cargoHash = "sha256-ShStjDSeXCSLU1u2SkAS3HCeRDAOpvNH71Sm/787RM0=";

    nativeBuildInputs = [
      pkg-config
      rustPlatform.bindgenHook
      llvmPackages.clang
    ];

    buildInputs = [
      ffmpeg_7
      sqlite
    ];

    LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
  };
in
writeShellApplication {
  name = "blissify";
  runtimeInputs = [ coreutils ]; # for id
  text = ''
    export MPD_HOST="''${XDG_RUNTIME_DIR:-/tmp/rmpc-$(id -u)}/mpd/socket"
    exec ${blissify-unwrapped}/bin/blissify "$@"
  '';

  passthru = { inherit blissify-unwrapped; };
  meta = blissify-unwrapped.meta;
}
