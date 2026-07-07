{
  pkgs ? import <nixpkgs> { },
  cpuArch ? "generic",
}:

let
  isAarch64 = pkgs.stdenv.hostPlatform.isAarch64;
  mpd-minimal = pkgs.stdenv.mkDerivation {
    pname = "mpd-minimal";
    version = "0.25-git";

    src = pkgs.fetchFromGitHub {
      owner = "MusicPlayerDaemon";
      repo = "MPD";
      rev = "master";
      hash = "sha256-6P6FuSB1Y4ye86E+zma2eoNoewZA5PqCWpC8sKNPzfk=";
    };

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

      "-Dpulse=disabled"
      "-Dfaad=disabled"
      "-Dwavpack=disabled"
      "-Dipv6=disabled"
      "-Diconv=disabled"
      "-Ddocumentation=disabled"
      "-Dinotify=false"
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
      "-Dmms=disabled"
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
    ++ (pkgs.lib.optionals (cpuArch != "generic") (
      if isAarch64 then
        [
          "-Dc_args=-mcpu=${cpuArch}"
          "-Dcpp_args=-mcpu=${cpuArch}"
        ]
      else
        [
          "-Dc_args=-march=${cpuArch}"
          "-Dcpp_args=-march=${cpuArch}"
        ]
    ));
  };

in
pkgs.writeShellApplication {
  name = "rmpc";

  runtimeInputs = [
    mpd-minimal
    pkgs.mpd-mpris
    pkgs.rmpc
  ];

  text = ''
        mkdir -p ~/.local/share/mpd/playlists
    		mkdir -p /tmp/rmpc/cache
    		mkdir -p ~/.lyrics
        SOCKET="/tmp/mpd_socket"
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

        trap 'kill $MPD_PID $MPRIS_PID 2>/dev/null || true' EXIT

        ${pkgs.rmpc}/bin/rmpc "$@"
        rm -f "$SOCKET"
  '';
}
