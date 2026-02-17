{ pkgs, ... }:
{
  scripts = pkgs.stdenv.mkDerivation {
    name = "pscripts";
    # References scripts directory at the flake root
    src = ../scripts/bin;
    installPhase = ''
      mkdir -p $out/bin
      cp -r $src/* $out/bin/
      chmod -R +x $out/bin/
    '';
  };

  scriptsManPgs = pkgs.stdenv.mkDerivation {
    name = "pscripts-manpgs";
    # References scripts directory at the flake root
    src = ../scripts/man;
    installPhase = ''
      mkdir -p $out/share/man/man1
      find $src -name "*.1" -exec install -m 644 {} $out/share/man/man1/ \;
    '';
  };
}
