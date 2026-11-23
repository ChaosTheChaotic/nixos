{
  pkgs,
  arch,
  mpdSrc,
  stdenv ? pkgs.stdenv,
}:

let
  blissify = pkgs.callPackage ./blissify.nix { };
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
      "-Ddaemon=false"
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
      blissify
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
    mkdir -p ~/.local/share/mpd/playlists
    mkdir -p ~/.local/share/bliss-rs
    mkdir -p /tmp/rmpc/cache
    mkdir -p ~/.lyrics
    SOCKET="/tmp/mpd_socket"
    # mpc and blissify both find MPD through this
    export MPD_HOST="$SOCKET"
    rm -f "$SOCKET"

    mpd --no-daemon &
    MPD_PID=$!

    # Wait until the MPD Unix socket is created
    for _ in {1..30}; do
        if [ -S "$SOCKET" ]; then
            break
        fi
        sleep 0.1
    done

    mpd-mpris -network unix -host "$SOCKET" >/dev/null 2>&1 &
    MPRIS_PID=$!

    # Background blissify sync in its own process group so it can be killed as one
    setsid ${blissSync}/bin/bliss-sync >>"$HOME/.local/share/bliss-rs/sync.log" 2>&1 &
    SYNC_PID=$!

    trap 'kill $MPD_PID $MPRIS_PID 2>/dev/null || true; kill -- -$SYNC_PID 2>/dev/null || true' EXIT

    ${pkgs.rmpc}/bin/rmpc "$@"
    rm -f "$SOCKET"
  '';
}
