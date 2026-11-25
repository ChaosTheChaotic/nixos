#! /usr/bin/env bash

usage() {
	cat <<'USAGE'
scr shot [file]          one PNG of the active scanout -> ~/Screenshots
scr rec start [name]     record in the background; new segment on every VT change
scr rec stop|toggle|status
scr stream <url>         live stream (srt://, rtmp://, rtsp://, udp://); Ctrl+C stops
scr planes               list the planes/CRTCs ffmpeg sees (to find SCR_PLANE / SCR_CRTC)

env: SCR_DEVICE=/dev/dri/cardN  SCR_PLANE=<id>  SCR_CRTC=<id>  SCR_FPS=30
     SCR_PIPE=vaapi|cpu  SCR_AUDIO=<pulse source, e.g. @DEFAULT_MONITOR@>
     SCR_BITRATE=4M (stream)  SCR_OUTDIR=~/Screenshots (files)
USAGE
}

ff="${SCR_FFMPEG:-${SCR_FFMPEG_DEFAULT:?}}"
home="${SCR_HOME:-${HOME:-/tmp}}"
rt="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
fps="${SCR_FPS:-30}"
pipe="${SCR_PIPE:-${SCR_DEFAULT_PIPE:?}}"
outdir="${SCR_OUTDIR:-$home/Screenshots}"
state="${XDG_STATE_HOME:-$home/.local/state}/scr"
pidfile="$rt/scr-rec.pid"

# Hotkey daemons (triggerhappy) start us without a login environment
if [ -z "${PULSE_SERVER:-}" ] && [ -S "$rt/pulse/native" ]; then
	export PULSE_SERVER="unix:$rt/pulse/native"
fi

active_tty() { cat /sys/class/tty/tty0/active 2>/dev/null || echo tty0; }

# First connected connector decides which DRM card we capture
find_card() {
	local s card
	for s in /sys/class/drm/card*-*/status; do
		[ -e "$s" ] || continue
		if [ "$(cat "$s")" = connected ]; then
			card="${s#/sys/class/drm/}"
			echo "/dev/dri/${card%%-*}"
			return 0
		fi
	done
	return 1
}

dev="${SCR_DEVICE:-}"
if [ -z "$dev" ]; then
	dev="$(find_card)" || {
		echo "scr: no connected DRM connector found" >&2
		exit 1
	}
fi

# kmsgrab input options
# -f kmsgrab -i - must come last
in_args=(-device "$dev" -framerate "$fps")
if [ -n "${SCR_CRTC:-}" ]; then in_args+=(-crtc_id "$SCR_CRTC"); fi
if [ -n "${SCR_PLANE:-}" ]; then in_args+=(-plane_id "$SCR_PLANE"); fi
in_args+=(-f kmsgrab -i -)

# vaapi, GPU maps the (possibly tiled/compressed) scanout buffer
# cpu, plain mmap of a LINEAR framebuffer, tiled buffers come out scrambled
if [ "$pipe" = vaapi ]; then
	vf_video="hwmap=derive_device=vaapi,scale_vaapi=format=nv12"
	vf_shot="hwmap=derive_device=vaapi,scale_vaapi=format=nv12,hwdownload,format=nv12"
else
	vf_video="hwdownload,format=bgr0,format=yuv420p"
	vf_shot="hwdownload,format=bgr0"
fi

enc_rec() {
	if [ "$pipe" = vaapi ]; then
		echo -c:v h264_vaapi -qp 23
	else
		echo -c:v libx264 -preset ultrafast -crf 22 -pix_fmt yuv420p
	fi
}

enc_stream() {
	local br="${SCR_BITRATE:-4M}"
	if [ "$pipe" = vaapi ]; then
		echo -c:v h264_vaapi -b:v "$br" -maxrate "$br" -bf 0 -g $((fps * 2))
	else
		echo -c:v libx264 -preset veryfast -tune zerolatency -b:v "$br" -maxrate "$br" -bufsize "$br" -g $((fps * 2)) -pix_fmt yuv420p
	fi
}

# Optional audio input via system audio
audio_in=()
if [ -n "${SCR_AUDIO:-}" ]; then
	audio_in=(-thread_queue_size 512 -f pulse -i "$SCR_AUDIO")
fi

cmd_shot() {
	local out="${1:-$outdir/$(date +%Y%m%d-%H%M%S)-$(active_tty).png}"
	mkdir -p "$(dirname "$out")"
	"$ff" -nostdin -loglevel error -y "${in_args[@]}" -vf "$vf_shot" -frames:v 1 "$out"
	echo "$out"
}

cmd_planes() {
	"$ff" -nostdin -loglevel debug "${in_args[@]}" -frames:v 1 -f null - 2>&1 |
		grep -Ei 'plane|crtc|framebuffer' || true
}

cmd_stream() {
	local url="${1:?scr stream <url>}" fmt codec_a=()
	case "$url" in
		rtmp://*) fmt=flv ;;
		rtsp://*) fmt=rtsp ;;
		*) fmt=mpegts ;;
	esac
	if [ -n "${SCR_AUDIO:-}" ]; then codec_a=(-c:a aac -b:a 128k); fi
	# shellcheck disable=SC2046
	exec "$ff" -nostdin -loglevel warning "${in_args[@]}" "${audio_in[@]}" \
		-vf "$vf_video" $(enc_stream) "${codec_a[@]}" -f "$fmt" "$url"
}

rec_loop() {
	local base="$1" n=0 child=0 stop=0 short=0 tty out t0 t1
	trap 'stop=1; if [ "$child" -ne 0 ]; then kill -TERM "$child" 2>/dev/null || true; fi' TERM INT
	mkdir -p "$outdir"
	while [ "$stop" -eq 0 ]; do
		n=$((n + 1))
		tty="$(active_tty)"
		out="$outdir/$base-$tty-$(printf '%03d' "$n").mkv"
		local codec_a=()
		if [ -n "${SCR_AUDIO:-}" ]; then codec_a=(-c:a libopus -b:a 128k); fi
		t0=$SECONDS
		# shellcheck disable=SC2046
		"$ff" -nostdin -loglevel warning -y "${in_args[@]}" "${audio_in[@]}" \
			-vf "$vf_video" $(enc_rec) "${codec_a[@]}" "$out" &
		child=$!
		# Follow VT switches, finalize this segment and start a new one on the new VT
		while kill -0 "$child" 2>/dev/null; do
			if [ "$(active_tty)" != "$tty" ]; then
				kill -TERM "$child" 2>/dev/null || true
				break
			fi
			sleep 0.5
		done
		wait "$child" || true
		wait "$child" 2>/dev/null || true
		child=0
		[ -s "$out" ] || rm -f "$out"
		t1=$SECONDS
		# Give up if ffmpeg keeps dying instantly
		if [ $((t1 - t0)) -lt 3 ] && [ "$stop" -eq 0 ]; then
			short=$((short + 1))
			if [ "$short" -ge 10 ]; then
				echo "scr: ffmpeg keeps exiting immediately; giving up" >&2
				break
			fi
			sleep 1
		else
			short=0
		fi
	done
	rm -f "$pidfile"
}

rec_running() {
	[ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null
}

cmd_rec() {
	local sub="${1:-}"
	case "$sub" in
		start)
			if rec_running; then
				echo "scr: already recording"
				return 0
			fi
			mkdir -p "$state"
			setsid -f "$0" _recloop "${2:-rec-$(date +%Y%m%d-%H%M%S)}" >>"$state/rec.log" 2>&1
			sleep 0.3
			echo "recording -> $outdir (log: $state/rec.log)"
			;;
		stop)
			if rec_running; then
				kill -TERM "$(cat "$pidfile")"
				echo "stopping"
			else
				echo "not recording"
			fi
			;;
		toggle)
			if rec_running; then cmd_rec stop; else cmd_rec start; fi
			;;
		status)
			if rec_running; then echo "recording (pid $(cat "$pidfile"))"; else echo "idle"; fi
			;;
		*)
			usage
			exit 2
			;;
	esac
}

case "${1:-}" in
	shot)
		shift
		cmd_shot "$@"
		;;
	rec)
		shift
		cmd_rec "$@"
		;;
	stream)
		shift
		cmd_stream "$@"
		;;
	planes) cmd_planes ;;
	_recloop)
		shift
		echo $$ >"$pidfile"
		rec_loop "$@"
		;;
	*)
		usage
		exit 2
		;;
esac
