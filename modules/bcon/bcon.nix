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

let
  substitutedOld = "if sg.key.glyph_id > 0 && sg.cell_span > 1 {";
  substitutedNew = ''
    let substituted = sg.key.glyph_id > 0
        && (sg.cell_span > 1
            || font_main_fontdue
                .as_ref()
                .map_or(false, |f| f.lookup_glyph_index(sg.ch) != sg.key.glyph_id));
    let by_id_ok = substituted || matches!(font_style, font::lcd_atlas::FontStyle::Regular);
    if sg.key.glyph_id > 0 && sg.cell_span > 1 {'';

  byIdOld = "} else if sg.key.glyph_id > 0 && sg.cell_span == 1 {";
  byIdNew = "} else if by_id_ok && sg.key.glyph_id > 0 && sg.cell_span == 1 {";

  blankOld = "// glyph_id == 0: fall through to char-based rendering";
  blankNew = ''
    if !ligature_drawn && by_id_ok && sg.key.glyph_id > 0 {
        let blank = font_main_fontdue.as_ref().map_or(false, |f| {
            let m = f.metrics_indexed(sg.key.glyph_id, 64.0);
            m.width == 0 || m.height == 0
        });
        if blank {
            ligature_drawn = true;
        }
    }
    // glyph_id == 0: fall through to char-based rendering'';

  italicOld = "// Skip continuation cells (width=0), space, NUL";
  italicNew = ''
    if cell.attrs.contains(crate::terminal::grid::CellAttrs::ITALIC) {
        self.flush_segment_internal();
        col += 1;
        continue;
    }
    // Skip continuation cells (width=0), space, NUL'';
in
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

  postPatch = ''
        find . -type f -name '*.rs' -exec sed -i 's|"/bin/login"|"/run/current-system/sw/bin/login"|g' {} +

    		sed -i '/0x2328/a\
    0x23ED..=0x23EF |\
    0x23F1..=0x23F2 |' src/font/emoji.rs

        substituteInPlace src/font/shaper.rs \
          --replace-fail ${lib.escapeShellArg italicOld} ${lib.escapeShellArg italicNew}

        substituteInPlace src/main.rs \
          --replace-fail ${lib.escapeShellArg substitutedOld} ${lib.escapeShellArg substitutedNew} \
          --replace-fail ${lib.escapeShellArg byIdOld} ${lib.escapeShellArg byIdNew} \
          --replace-fail ${lib.escapeShellArg blankOld} ${lib.escapeShellArg blankNew}

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
