{
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  llvmPackages,
  ffmpeg_7,
  sqlite,
}:

rustPlatform.buildRustPackage rec {
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
}
