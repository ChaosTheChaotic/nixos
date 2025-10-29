{ lib, pkgs, scriptsDir ? ./. }:

let
  scriptFiles = lib.filterAttrs (name: type: type == "regular") (builtins.readDir scriptsDir);
  scriptDers = lib.mapAttrsToList (name: type: pkgs.writeShellScriptBin name (builtins.readFile (scriptsDir + "/${name}")) scriptFiles);
in
  pkgs.symlinkJoin {
    name = "pscripts";
    paths = scriptDers;
  }
