#!/usr/bin/env bash

if [ -n "${__ERR_SH_SOURCED:-}" ]; then
  return 0
fi
__ERR_SH_SOURCED=1

source "$UTIL_SCRIPT_DIR/colors.sh"

# Cannot use check_install due to a circular dependency issue as it requires this
if command -v notify-send &>/dev/null; then
  HAS_NOTIFY_SEND=true
else
  HAS_NOTIFY_SEND=false
fi

function fatal() {
  local msg="$1"
  printf "${Red}[FATAL]: %s${Reset}" "$msg"
  if $HAS_NOTIFY_SEND; then
    notify-send --urgency=critical "[FATAL]" "$msg"
  fi
}

function warn() {
  local msg="$1"
  printf "${Yellow}[WARN]: %s${Reset}" "$msg"
  if $HAS_NOTIFY_SEND; then
    notify-send --urgency=normal "[WARN]" "$msg"
  fi
}

function info() {
  printf "[INFO]: %s" "$1"
}
