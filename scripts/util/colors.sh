#!/usr/bin/env bash

if [ -n "${__COLORS_SH_SOURCED:-}" ]; then
  return 0
fi
__COLORS_SH_SOURCED=1

# Regular Colors
Black='\033[0;30m'
Red='\033[0;31m'
Green='\033[0;32m'
Yellow='\033[0;33m'
Blue='\033[0;34m'
Purple='\033[0;35m'
Cyan='\033[0;36m'
White='\033[0;37m'

# Bold Colors (often appear as "light" colors in terminals)
BBlack='\033[1;30m'
BRed='\033[1;31m'
BGreen='\033[1;32m'
BYellow='\033[1;33m'
BBlue='\033[1;34m'
BPurple='\033[1;35m'
BCyan='\033[1;36m'
BWhite='\033[1;37m'

# Other Styles
Underline='\033[4m'
Inverse='\033[7m'

# Reset variable to return to default terminal color/style
Reset='\033[0m'
