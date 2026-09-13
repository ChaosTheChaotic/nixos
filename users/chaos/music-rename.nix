{ pkgs, ... }:

let
  musicRenamer = pkgs.writeShellScriptBin "music-renamer" ''
    MUSIC_DIR="$HOME/Music"

    base_ffprobe_cmd() {
    	${pkgs.ffmpeg}/bin/ffprobe -loglevel error -show_entries $1="$2" -of default=noprint_wrappers=1:nokey=1 "$3" | head -n1
    }

    get_music_tag() {
    	val=$(base_ffprobe_cmd "format_tags" "$1" "$2")
    	if [ -z "$val" ]; then
    		val=$(base_ffprobe_cmd "stream_tags" "$1" "$2")
    	fi
    	echo -n "$val"
    }

    sanitize_str() {
    	echo "$1" | tr '/' '-' | tr ' ' '_' | tr '.' '_'
    }

    mkdir -p "$MUSIC_DIR"

    # Check for files that finish writing or are moved into the directory
    ${pkgs.inotify-tools}/bin/inotifywait -m "$MUSIC_DIR" -e close_write -e moved_to -e create --format '%w%f' |
    	while read -r FILE; do
    	  if [ ! -f "$FILE" ]; then continue; fi

    	  # Extract metadata
    	  TITLE=$(get_music_tag "title" "$FILE")
    	  ARTIST=$(get_music_tag "artist" "$FILE")

    		# Dont attempt rename if we dont have both
    	  if [ -n "$TITLE" ] && [ -n "$ARTIST" ]; then
    	      TITLE=$(sanitize_str "$TITLE")
    	      ARTIST=$(sanitize_str "$ARTIST")

    	      DIR=$(dirname "$FILE")
    	      EXT="''${FILE##*.}"
    	      NEW_NAME="''${DIR}/''${TITLE}_''${ARTIST}.''${EXT}"

    	      if [ "$FILE" != "$NEW_NAME" ]; then
    	          mv -n "$FILE" "$NEW_NAME"
    	      fi
    	  fi
    	done
  '';
in
{
  systemd.user.services.music-rename = {
    Unit = {
      Description = "Auto-rename music files in ~/Music to Title_Artist format";
      After = [ "default.target" ];
    };
    Service = {
      ExecStart = "${musicRenamer}/bin/music-renamer";
      Restart = "always";
      RestartSec = "5";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
