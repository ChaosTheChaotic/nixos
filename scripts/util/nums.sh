#!/usr/bin/env bash

if [ -n "${__NUMS_SH_SOURCED:-}" ]; then
  return 0
fi
__NUMS_SH_SOURCED=1

function is_num() { [[ "$1" =~ ^[0-9]+$ ]]; }

is_percent() {
  [[ "$1" =~ ^[0-9]+$ ]] && (($1 >= 0 && $1 <= 100))
}
