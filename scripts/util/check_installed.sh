#!/usr/bin/env bash

if [ -n "${__CHECK_INSTALLED_SH_SOURCED:-}" ]; then
  return 0
fi
__CHECK_INSTALLED_SH_SOURCED=1

source "$UTIL_SCRIPT_DIR/err.sh"

function check_installed() {
  if ! command -v "$1" &>/dev/null; then
    fatal "Command $1 not installed"
    exit 1
  fi
}
