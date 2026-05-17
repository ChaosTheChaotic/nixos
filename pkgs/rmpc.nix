{ pkgs ? import <nixpkgs> {} }:

let
  mpd-minimal = pkgs.gcc14Stdenv.mkDerivation {
    pname = "mpd-minimal";
    version = "0.25-git";

    src = pkgs.fetchFromGitHub {
      owner = "MusicPlayerDaemon";
      repo = "MPD";
      rev = "master"; 
      hash = "sha256-ehlpqm7RUf/Q3xTqtyJf7BVhjEQq+u76ptxbllzJKFc="; 
    };

    mesonBuildType = "release";

    nativeBuildInputs = with pkgs; [
      meson
      ninja
      pkg-config
    ];

    buildInputs = with pkgs; [
      liburing dbus zlib boost fmt mpg123 libid3tag libvorbis
      libsndfile flac opus ffmpeg chromaprint pcre2 icu pipewire alsa-lib
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
    ];
  };

in
pkgs.writeShellApplication {
  name = "rmpc";
  
  runtimeInputs = [ mpd-minimal pkgs.rmpc ];
  text = ''
    SOCKET="$HOME/.config/mpd/socket"
		rm -f "$SOCKET"
    mpd --no-daemon &
    MPD_PID=$!

    # Ensure mpd is automatically killed when rmpc exits or is interrupted
    trap 'kill $MPD_PID 2>/dev/null || true' EXIT

    # Wait until the MPD Unix socket is created
    for _ in {1..30}; do
        if [ -S "$SOCKET" ]; then
            break
        fi
        sleep 0.1
    done

    ${pkgs.rmpc}/bin/rmpc "$@"
  '';
}
