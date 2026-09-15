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
}:

rustPlatform.buildRustPackage rec {
  pname = "bcon";
  version = "1.4.0";

  src = fetchFromGitHub {
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

  postPatch = ''
    find . -type f -name '*.rs' -exec sed -i 's|"/bin/login"|"/run/current-system/sw/bin/login"|g' {} +
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
