{ config, ... }:
{
  _module.args.palette = import ../lib/palette.nix {
    inherit (config.lib.stylix) colors;
  };
}
