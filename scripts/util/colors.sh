#!/usr/bin/env bash

if [ -n "${__COLORS_SH_SOURCED:-}" ]; then
  return 0
fi
__COLORS_SH_SOURCED=1

# Regular Colors
readonly Black='\033[0;30m'
readonly Red='\033[0;31m'
readonly Green='\033[0;32m'
readonly Yellow='\033[0;33m'
readonly Blue='\033[0;34m'
readonly Purple='\033[0;35m'
readonly Cyan='\033[0;36m'
readonly White='\033[0;37m'
readonly
# Bold Colors (often appear as "light" colors in terminals)
readonly BBlack='\033[1;30m'
readonly BRed='\033[1;31m'
readonly BGreen='\033[1;32m'
readonly BYellow='\033[1;33m'
readonly BBlue='\033[1;34m'
readonly BPurple='\033[1;35m'
readonly BCyan='\033[1;36m'
readonly BWhite='\033[1;37m'
readonly
# Other Styles
readonly Underline='\033[4m'
readonly Inverse='\033[7m'
readonly
# Reset variable to return to default terminal color/style
readonly Reset='\033[0m'
