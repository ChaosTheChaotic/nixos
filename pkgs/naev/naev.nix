{
  lib,
  stdenv,
  fetchFromCodeberg,
  fetchFromGitHub,
  fetchurl,
  unzip,
  pkg-config,
  python3,
  sdl3,
  dav1d,
  opus,
  libgit2,
  libzip,
  enet,
  freetype,
  glpk,
  intltool,
  libpng,
  libunibreak,
  libvorbis,
  libxml2,
  luajit,
  meson,
  ninja,
  openal,
  openblas,
  pcre2,
  physfs,
  suitesparse,
  libyaml,
  cmark,
  dbus,
  rustPlatform,
  cargo,
  rustc,
  llvmPackages,
  rust-bindgen,
  openssl,
  naevSrc ? null,
}:

let
  lyaml = fetchFromGitHub {
    owner = "gvvaughan";
    repo = "lyaml";
    tag = "v6.2.8";
    hash = "sha256-ADLXi38sAs9ifQ4HJoYzgdp/dw0axGmVCtqJjpqWcmQ=";
  };
  nativefiledialog-extended = fetchFromGitHub {
    owner = "btzy";
    repo = "nativefiledialog-extended";
    tag = "v1.2.1";
    hash = "sha256-GwT42lMZAAKSJpUJE6MYOpSLKUD5o9nSe9lcsoeXgJY=";
  };
  nativefiledialog-extended-patch = fetchurl {
    url = "https://wrapdb.mesonbuild.com/v2/nativefiledialog-extended_1.2.1-1/get_patch";
    hash = "sha256-BEouiB2HTVWokrYc9VOqdnjRwPBs+us5obQ/NMqXawk=";
  };

  cargoDeps = rustPlatform.importCargoLock {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "gltf-1.4.1" = "sha256-FL0QQSfLq7CjazE/R7P3AwCCCptHo4gtJYa3F0iG7Jc=";
      "image-0.25.9" = "sha256-mAlC+wi4lLW5oMbz36vT1/+7Xad4f//iwrHqiIsGLus=";
    };
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "naev";
  version = "0.13.5";

  RUSTC = "${rustc}/bin/rustc";
  CARGO = "${cargo}/bin/cargo";
  CARGO_NET_OFFLINE = "true";
  OPENSSL_NO_VENDOR = "1";

  cargoDeps = cargoDeps;

  src =
    if naevSrc != null then
      naevSrc
    else
      fetchFromCodeberg {
        owner = "naev";
        repo = "naev";
        rev = "v${finalAttrs.version}";
        hash = "sha256-c9xs12SQHNHkIlT1LEKDogpg3sMC7cUH5QPQp7tfs7o=";
        fetchSubmodules = true;
      };

  buildInputs = [
    sdl3
    dav1d
    opus
    libgit2
    libzip
    enet
    freetype
    glpk
    libpng
    libunibreak
    libvorbis
    libxml2
    luajit
    openal
    openblas
    pcre2
    physfs
    suitesparse
    libyaml
    cmark
    dbus
    openssl
  ];

  nativeBuildInputs = [
    rustPlatform.cargoSetupHook
    (python3.withPackages (
      ps: with ps; [
        pyyaml
        mutagen
      ]
    ))
    meson
    ninja
    pkg-config
    intltool
    unzip
    cargo
    rustc
    llvmPackages.clang
    rust-bindgen
  ];

  postUnpack = ''
    cp ${./Cargo.lock} ''${sourceRoot}/Cargo.lock
  '';

  mesonFlags = [
    "-Ddocs_c=disabled"
    "-Ddocs_lua=disabled"
    "-Dluajit=enabled"
  ];

  postPatch = ''
    patchShebangs .

    mkdir -p subprojects
    cp -r ${lyaml} subprojects/lyaml-6.2.8
    chmod -R +w subprojects/lyaml-6.2.8
    cp -r subprojects/packagefiles/lyaml/* subprojects/lyaml-6.2.8 2>/dev/null || true

    cp -r ${nativefiledialog-extended} subprojects/nativefiledialog-extended-1.2.1
    chmod -R +w subprojects/nativefiledialog-extended-1.2.1
    tmp=$(mktemp -d)
    unzip ${nativefiledialog-extended-patch} -d $tmp
    cp -r $tmp/*/* subprojects/nativefiledialog-extended-1.2.1
  '';

  postConfigure = ''
    mkdir -p cargo-home

    if [ -f "$sourceRoot/.cargo/config.toml" ]; then
      cp "$sourceRoot/.cargo/config.toml" cargo-home/config.toml
    elif [ -f "$sourceRoot/.cargo/config" ]; then
      cp "$sourceRoot/.cargo/config" cargo-home/config.toml
    else
      FOUND_CONFIG=$(find "$NIX_BUILD_TOP" -name "config.toml" | grep ".cargo" | head -n 1)
      if [ -n "$FOUND_CONFIG" ]; then
        cp "$FOUND_CONFIG" cargo-home/config.toml
      else
        echo "Error: cargoSetupHook did not generate an offline configuration."
        exit 1
      fi
    fi

    cp ${./Cargo.lock} Cargo.lock 2>/dev/null || true
    mkdir -p src
    cp ${./Cargo.lock} src/Cargo.lock 2>/dev/null || true
  '';

  meta = {
    description = "2D action/rpg space game";
    mainProgram = "naev";
    homepage = "https://www.naev.org";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ ralismark ];
    platforms = lib.platforms.linux;
  };
})
