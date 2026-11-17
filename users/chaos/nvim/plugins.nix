# Every flake with the name scheme nvp-* (flake = false) becomes built vim plugin available to other modules as vp.*
# To add a plugin add nvp-{} to flake.nix and use vp.{}
{
  inputs,
  pkgs,
  lib,
  ...
}:

let
  prefix = "nvp-";

  sources = lib.mapAttrs' (n: v: lib.nameValuePair (lib.removePrefix prefix n) v) (
    lib.filterAttrs (n: _: lib.hasPrefix prefix n) inputs
  );

  # Plugins that require other plugins at runtime.
  deps = {
    telescope-nvim = [ "plenary-nvim" ];
    lazygit-nvim = [ "plenary-nvim" ];
    flutter-tools-nvim = [
      "plenary-nvim"
      "dressing-nvim"
    ];
  };

  vp = lib.mapAttrs (
    name: src:
    pkgs.vimUtils.buildVimPlugin {
      pname = name;
      version = src.shortRev or src.lastModifiedDate or "unknown";
      inherit src;
      dependencies = map (d: vp.${d}) (deps.${name} or [ ]);
      doCheck = false;
      doInstallCheck = false;
    }
  ) sources;
in
{
  _module.args.vp = vp;
}
