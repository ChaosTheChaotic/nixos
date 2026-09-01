{
  homeDir,
  ...
}:

let
	NIX_HOME_BASE = "${homeDir}/nixos-cfg";
  SCRIPT_BASE_DIR = "${NIX_HOME_BASE}/scripts";
in
{
  UTIL_SCRIPT_DIR = "${SCRIPT_BASE_DIR}/util";
  BIN_SCRIPT_DIR = "${SCRIPT_BASE_DIR}/bin";
  WALLPAPER_DIR = "${NIX_HOME_BASE}/wallpapers";
  NIX_CFG_DIR = "${NIX_HOME_BASE}";
}
