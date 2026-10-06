#!/usr/bin/env bash
set -euo pipefail
export PATH="@path@${PATH:+:$PATH}"

real_bin='@unwrapped@'
backend="${FBBROWSER_BACKEND:-@defaultBackend@}"
dry_run=0

die()  { printf 'fbbrowser: error: %s\n' "$*" >&2; exit 1; }
warn() { printf 'fbbrowser: warning: %s\n' "$*" >&2; }
note() { printf 'fbbrowser: %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: fbbrowser [options] [URL]

Options:
  -b, --backend <auto|eglfs|fb>  Qt platform backend (default: $backend)
        auto   eglfs if a usable DRM/KMS node exists, else linuxfb
        eglfs  accelerated, needs /dev/dri/card* (kernel mode setting)
        fb     linuxfb, unaccelerated, needs /dev/fb*
  -n, --dry-run                  Print the chosen backend and environment, don't start
  -h, --help                     Show this help

Only one URL is accepted (the browser reads just argv[1]). Chromium flags
cannot be passed as arguments; use QTWEBENGINE_CHROMIUM_FLAGS instead.

Environment:
  FBBROWSER_BACKEND          Default for --backend
  FBBROWSER_CONFIG_DIR       Directory holding config.json
                             (default: \${XDG_CONFIG_HOME:-~/.config}/fbbrowser)
  FBBROWSER_FB_DEVICE        Framebuffer node for linuxfb (default: first usable /dev/fb*)
  FBBROWSER_KEYBOARD_DEV     Pin keyboard to an evdev node (eventN or full path)
  FBBROWSER_MOUSE_DEV        Pin mouse to an evdev node
  FBBROWSER_TOUCHSCREEN_DEV  Pin touchscreen to an evdev node
                             Setting any *_DEV switches Qt from libinput
                             (auto-discovery, the default) to plain evdev.
  QT_QPA_PLATFORM            If set and backend is 'auto', used as-is (no detection)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -b|--backend)
      [ $# -ge 2 ] || die "$1 needs a value (auto, eglfs or fb)"
      backend=$2; shift 2 ;;
    --backend=*) backend=${1#*=}; shift ;;
    -n|--dry-run) dry_run=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) die "unknown option '$1' (the browser would treat it as a URL; see --help)" ;;
    *) break ;;
  esac
done
[ $# -le 1 ] || die "at most one URL is accepted"
url=${1:-}

case "$backend" in
  auto|eglfs|fb) ;;
  linuxfb) backend=fb ;;
  *) die "invalid backend '$backend' (expected auto, eglfs or fb)" ;;
esac

usable_node() {
  local n
  for n in "$@"; do
    if [ -c "$n" ] && [ -r "$n" ] && [ -w "$n" ]; then
      printf '%s\n' "$n"
      return 0
    fi
  done
  return 1
}

any_node() {
  local n
  for n in "$@"; do
    if [ -c "$n" ]; then return 0; fi
  done
  return 1
}

explain_unusable() {
  local label=$1 hint=$2
  shift 2
  if any_node "$@"; then
    warn "$label device exists but $(id -un) cannot read/write it (groups: $(id -nG))."
    warn "  Add the user to the '$hint' group, or log in on the local seat."
  else
    warn "no $label device found."
  fi
}

evdev_path() { case "$1" in /*) printf '%s' "$1" ;; *) printf '/dev/input/%s' "$1" ;; esac; }

drm_node=$(usable_node /dev/dri/card* || true)
if [ -n "${FBBROWSER_FB_DEVICE:-}" ]; then
  fb_node=$FBBROWSER_FB_DEVICE
else
  fb_node=$(usable_node /dev/fb* || true)
fi

resolved=$backend
if [ "$backend" = auto ]; then
  if [ -n "${QT_QPA_PLATFORM:-}" ]; then
    resolved=env
    note "backend: using QT_QPA_PLATFORM=$QT_QPA_PLATFORM from the environment"
  elif [ -n "$drm_node" ]; then
    resolved=eglfs
  elif [ -n "$fb_node" ]; then
    resolved=fb
    note "backend: no usable DRM node, falling back to linuxfb ($fb_node)"
    explain_unusable DRM video /dev/dri/card*
  else
    explain_unusable DRM video /dev/dri/card*
    explain_unusable framebuffer video /dev/fb*
    die "no usable display device for either eglfs or linuxfb"
  fi
else
  # Forced: honour the request, but warn so the failure is explainable.
  if [ "$backend" = eglfs ] && [ -z "$drm_node" ]; then
    explain_unusable DRM video /dev/dri/card*
    warn "continuing anyway because --backend eglfs was forced"
  elif [ "$backend" = fb ] && [ -z "$fb_node" ]; then
    explain_unusable framebuffer video /dev/fb*
    warn "continuing anyway because --backend fb was forced"
  fi
fi

if [ "$resolved" != env ] && ! usable_node /dev/input/event* >/dev/null; then
  warn "no readable /dev/input/event* nodes: keyboard and mouse will not work."
  warn "  Add the user to the 'input' group."
fi

evdev=0
if [ -n "${FBBROWSER_KEYBOARD_DEV:-}" ]; then
  export QT_QPA_EVDEV_KEYBOARD_PARAMETERS="$(evdev_path "$FBBROWSER_KEYBOARD_DEV"):grab=1"
  evdev=1
fi
if [ -n "${FBBROWSER_MOUSE_DEV:-}" ]; then
  export QT_QPA_EVDEV_MOUSE_PARAMETERS="$(evdev_path "$FBBROWSER_MOUSE_DEV")"
  evdev=1
fi
if [ -n "${FBBROWSER_TOUCHSCREEN_DEV:-}" ]; then
  export QT_QPA_EVDEV_TOUCHSCREEN_PARAMETERS="$(evdev_path "$FBBROWSER_TOUCHSCREEN_DEV")"
  evdev=1
fi

export QT_QPA_ENABLE_TERMINAL_KEYBOARD=0

case "$resolved" in
  eglfs)
    export QT_QPA_PLATFORM=eglfs
    export QT_QPA_EGLFS_INTEGRATION=eglfs_kms
    if [ "$evdev" = 1 ]; then export QT_QPA_EGLFS_NO_LIBINPUT=1; fi
    ;;
  fb)
    export QT_QPA_PLATFORM="linuxfb:fb=${fb_node:-/dev/fb0}:nographicsmodeswitch=1"
    export QT_QPA_FB_FORCE_FULLSCREEN=1
    if [ "$evdev" = 1 ]; then export QT_QPA_FB_NO_LIBINPUT=1; fi
    case " ${QTWEBENGINE_CHROMIUM_FLAGS:-} " in
      *" --disable-gpu "*) ;;
      *) export QTWEBENGINE_CHROMIUM_FLAGS="--disable-gpu${QTWEBENGINE_CHROMIUM_FLAGS:+ $QTWEBENGINE_CHROMIUM_FLAGS}" ;;
    esac
    ;;
esac

case "$url" in ./*) url="file://$PWD/${url#./}" ;; esac

config_dir="${FBBROWSER_CONFIG_DIR:-${XDG_CONFIG_HOME:-${HOME:?HOME is not set}/.config}/fbbrowser}"
if [ "$dry_run" = 0 ]; then
  mkdir -p "$config_dir"
  if [ ! -e "$config_dir/config.json" ]; then
    cat >"$config_dir/config.json" <<'JSON'
{
  "url": "https://google.com",
  "wsServerPort": 0,
  "width": 0,
  "height": 0,
  "proxyHost": "",
  "proxyPort": 0
}
JSON
  fi
  cd "$config_dir"
fi

cmd=("$real_bin")
if [ -n "$url" ]; then cmd+=("$url"); fi

if [ "$dry_run" = 1 ]; then
  printf 'backend:    %s\n' "$resolved"
  printf 'config dir: %s\n' "$config_dir"
  while IFS= read -r name; do
    case "$name" in QT_QPA_*|QTWEBENGINE_*) printf '%s=%s\n' "$name" "${!name}" ;; esac
  done < <(compgen -e | sort)
  printf 'command:   '; printf ' %q' "${cmd[@]}"; printf '\n'
  exit 0
fi

if [ "$resolved" != fb ]; then
  exec "${cmd[@]}"
fi

cleanup() {
  if [ -t 1 ]; then setterm -cursor on || true; fi
  cat /dev/zero >"${fb_node:-/dev/fb0}" 2>/dev/null || true
}
trap cleanup EXIT
if [ -t 1 ]; then setterm -cursor off || true; fi
rc=0
"${cmd[@]}" || rc=$?
exit "$rc"
