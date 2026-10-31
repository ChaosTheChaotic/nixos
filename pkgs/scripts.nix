{ pkgs, ... }:

pkgs.stdenvNoCC.mkDerivation {
  name = "pscripts";
  src = ../scripts;
  installPhase = ''
    mkdir -p $out/bin $out/share/man/man1
    cp -r $src/bin/* $out/bin/
    chmod -R +x $out/bin/
    find $src/man -name '*.1' -exec install -m 644 {} $out/share/man/man1/ \;
  '';
}
