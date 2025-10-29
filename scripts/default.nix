{ lib, pkgs, scriptsDir ? ./. }:

let
  scriptNames = builtins.attrNames (lib.filterAttrs (name: type: type == "regular") (builtins.readDir scriptsDir));

  scripts = builtins.listToAttrs (lib.map (name: lib.nameValuePair name (pkgs.writeShellScriptBin name (builtins.readFile (scriptsDir + "/${name}")))) scriptNames);

in
  pkgs.symlinkJoin {
    name = "pscripts";
    paths = builtins.attrValues scripts;
  }
