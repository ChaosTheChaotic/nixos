{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  cmake,
  mesa,
  libGL,
  libdrm,
  libinput,
  libxkbcommon,
  seatd,
  wayland,
  dbus,
  systemd,
  fontconfig,
  freetype,
  libgbm,
  libglvnd,
  bconSrc ? null,
}:

rustPlatform.buildRustPackage rec {
  pname = "bcon";
  version = "1.4.0";

  src =
    if bconSrc != null then
      bconSrc
    else
      fetchFromGitHub {
        owner = "sanohiro";
        repo = "bcon";
        rev = "v${version}";
        hash = "sha256-Mv/FEFUYVPDk1h4P2s6a0s9ioGakzOxERJCk+vQcYr8=";
      };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    # Let nix fetch and git create deps in lockfile without having to add hashes for each
    allowBuiltinFetchGit = true;
  };

  patches = [
    ./bcon-kitty-placeholders.patch
    ./bcon-kitty-c1-anchored.patch
  ];

  postPatch = ''
        find . -type f -name '*.rs' -exec sed -i 's|"/bin/login"|"/run/current-system/sw/bin/login"|g' {} +

    		sed -i '/0x2328/a\
    0x23ED..=0x23EF |\
    0x23F1..=0x23F2 |' src/font/emoji.rs

        sed -z -E -i 's/(let mut ligature_drawn = false;[[:space:]]*if matches!\(font_style, )font::lcd_atlas::FontStyle::Regular\)/\1font::lcd_atlas::FontStyle::Regular | font::lcd_atlas::FontStyle::Bold)/' src/main.rs
        grep -q 'FontStyle::Regular | font::lcd_atlas::FontStyle::Bold' src/main.rs \
          || { echo "bcon patch: ligature style gate not found in src/main.rs" >&2; exit 1; }
  '';

  nativeBuildInputs = [
    pkg-config
    cmake
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    mesa
    libGL
    libdrm
    libinput
    libxkbcommon
    seatd
    wayland
    dbus
    systemd # libudev
    fontconfig
    freetype
    libgbm
    libglvnd
  ];

  NIX_LDFLAGS = [
    "--push-state"
    "--no-as-needed"
    "-lEGL"
    "-lGLESv2"
    "--pop-state"
  ];

  # bcons tests check real DRM/GPU/TTY which arent allowed in the nix sandbox
  doCheck = false;

  meta = {
    description = "GPU-accelerated terminal emulator for the Linux console (TTY), no X11/Wayland required";
    homepage = "https://github.com/sanohiro/bcon";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "bcon";
  };
}
