{
  pkgs,
  arch,
  mpdSrc,
  stdenv ? pkgs.stdenv,
}:

let
  blissify = pkgs.callPackage ./blissify.nix { };
  blissify-unwrapped = blissify.passthru.blissify-unwrapped;
  mpd-minimal = stdenv.mkDerivation {
    pname = "mpd-minimal";
    version = "0.25-git";

    src = mpdSrc;
    mesonBuildType = "release";

    nativeBuildInputs = with pkgs; [
      meson
      ninja
      pkg-config
    ];

    buildInputs = with pkgs; [
      liburing
      dbus
      zlib
      boost
      fmt
      mpg123
      libid3tag
      libvorbis
      libsndfile
      flac
      opus
      ffmpeg
      chromaprint
      pcre2
      icu
      pipewire
      alsa-lib
      tinyalsa
    ];

    mesonFlags = [
      "-Doptimization=3"
      "-Depoll=true"
      "-Deventfd=true"
      "-Dsignalfd=true"
      "-Dio_uring=enabled"
      "-Ddbus=enabled"
      "-Dchromaprint=enabled"
      "-Dmpg123=enabled"
      "-Did3tag=enabled"
      "-Dvorbis=enabled"
      "-Dsndfile=enabled"
      "-Dflac=enabled"
      "-Dffmpeg=enabled"
      "-Dpipewire=enabled"
      "-Dalsa=enabled"
      "-Dpcre=enabled"
      "-Dopus=enabled"
      "-Dicu=enabled"
      "-Dlocal_socket=true"
      "-Ddatabase=true"
      "-Dzlib=enabled"
      "-Dinotify=true"

      "-Dpulse=disabled"
      "-Dfaad=disabled"
      "-Dwavpack=disabled"
      "-Dipv6=disabled"
      "-Diconv=disabled"
      "-Ddocumentation=disabled"
      "-Dtcp=false"
      "-Dhtml_manual=false"
      "-Dmanpages=false"
      "-Ddoxygen=false"
      "-Dsyslog=disabled"
      "-Dsystemd=disabled"
      "-Dtest=false"
      "-Dfuzzer=false"
      "-Dlibfuzzer=false"
      "-Ddsd=false"
      "-Dupnp=disabled"
      "-Dlibmpdclient=disabled"
      "-Dneighbor=false"
      "-Dudisks=disabled"
      "-Dwebdav=disabled"
      "-Dcue=false"
      "-Dcdio_paranoia=disabled"
      "-Dcurl=disabled"
      "-Dnfs=disabled"
      "-Dsmbclient=disabled"
      "-Dqobuz=disabled"
      "-Dbzip2=disabled"
      "-Diso9660=disabled"
      "-Dzzip=disabled"
      "-Dadplug=disabled"
      "-Daudiofile=disabled"
      "-Dfluidsynth=disabled"
      "-Dgme=disabled"
      "-Dmad=disabled"
      "-Dmikmod=disabled"
      "-Dmodplug=disabled"
      "-Dopenmpt=disabled"
      "-Dmpcdec=disabled"
      "-Dsidplay=disabled"
      "-Dpsgplay=disabled"
      "-Dtremor=disabled"
      "-Dvgmstream=disabled"
      "-Dwildmidi=disabled"
      "-Dvorbisenc=disabled"
      "-Dlame=disabled"
      "-Dtwolame=disabled"
      "-Dshine=disabled"
      "-Dwave_encoder=false"
      "-Dlibsamplerate=disabled"
      "-Dsoxr=disabled"
      "-Dao=disabled"
      "-Dfifo=false"
      "-Dhttpd=false"
      "-Djack=disabled"
      "-Dopenal=disabled"
      "-Doss=disabled"
      "-Dpipe=false"
      "-Dshout=disabled"
      "-Dsnapcast=false"
      "-Dsndio=disabled"
      "-Dsolaris_output=disabled"
      "-Dexpat=disabled"
      "-Dnlohmann_json=disabled"
      "-Dsqlite=disabled"
      "-Dzeroconf=disabled"
    ]
    ++ arch.mesonCflags;
  };

  # Keeps blissifys database in step with MPDs
  # Started by the rmpc wrapper below (needs MPD_HOST pointing at the MPD socket)
  blissSync = pkgs.writeShellApplication {
    name = "bliss-sync";
    runtimeInputs = with pkgs; [
      mpc
      blissify-unwrapped
      coreutils
      util-linux
    ];
    text = ''
      cfg="$HOME/.local/share/bliss-rs/config.json"

      bliss_sync() {
        if [ -f "$cfg" ]; then
          nice -n 19 ionice -c 3 blissify update
        else
      		# On first run we analyse whole library (which can take a while)
      		# If rmpc is closed halfway through, the next update picks up from the rest
          nice -n 19 ionice -c 3 blissify init "$HOME/Music"
        fi
      }

      echo "[$(date -Is)] startup sync"
      mpc --wait update || true # make sure MPD has seen files added while it was off
      bliss_sync || true

      # MPD emits a database event whenever an update finishes
      # (inotify-triggered or manual), so no extra file watcher is needed.
      mpc idleloop database | while read -r _; do
      	# Debounce
        while read -r -t 10 _; do :; done
        echo "[$(date -Is)] database changed, syncing"
        bliss_sync || true
      done
    '';
  };

in
pkgs.writeShellApplication {
  name = "rmpc";

  runtimeInputs = [
    mpd-minimal
    pkgs.mpd-mpris
    pkgs.rmpc
    pkgs.util-linux # setsid
  ];

  text = ''
    RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/tmp/rmpc-$(id -u)}"
    SOCKET_DIR="$RUNTIME_DIR/mpd"
    SOCKET="$SOCKET_DIR/socket"

    mkdir -p "$SOCKET_DIR"
    mkdir -p ~/.local/share/mpd/playlists
    mkdir -p ~/.local/share/bliss-rs
    mkdir -p ~/.lyrics
    mkdir -p /tmp/rmpc/cache

    export MPD_HOST="$SOCKET"
    rm -f "$SOCKET"

    # MPD does not expand env vars in mpd.conf, so render the template
    MPD_CONF="$SOCKET_DIR/mpd.conf"
    sed "s|@SOCKET@|$SOCKET|g" "$HOME/.config/mpd/mpd.conf" > "$MPD_CONF"

    mpd "$MPD_CONF" &
    MPD_PID=$!

    for _ in {1..30}; do
      if [ -S "$SOCKET" ]; then break; fi
      sleep 0.1
    done
    if [ ! -S "$SOCKET" ]; then
      echo "mpd failed to start (config: $MPD_CONF)" >&2
      exit 1
    fi

    mpd-mpris -network unix -host "$SOCKET" >/dev/null 2>&1 &
    MPRIS_PID=$!

    setsid ${blissSync}/bin/bliss-sync >>"$HOME/.local/share/bliss-rs/sync.log" 2>&1 &
    SYNC_PID=$!

    cleanup() {
      kill "$MPD_PID" "$MPRIS_PID" 2>/dev/null || true
      kill -- "-$SYNC_PID" 2>/dev/null || true
      rm -f "$SOCKET"
    }
    trap cleanup EXIT

    # Decide whether to inject --address
    #   * --clean must be the only argument -> never inject with it
    #   * Respect a user-provided -a/--address (clap would reject a duplicate)
    inject_address=1
    for arg in "$@"; do
      case "$arg" in
        --clean)      inject_address=0 ;;
        -a|--address) inject_address=0 ;;
        --address=*)  inject_address=0 ;;
        -a?*)         inject_address=0 ;;   # -aVALUE form
      esac
    done

    rmpc_args=()
    if [ "$inject_address" -eq 1 ]; then
      rmpc_args+=(--address "$SOCKET")
    fi
    rmpc_args+=("$@")

    ${pkgs.rmpc}/bin/rmpc "''${rmpc_args[@]}"
  '';
}
