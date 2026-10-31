{
  pkgs,
}:

pkgs.stdenvNoCC.mkDerivation {
  pname = "sysstat";
  version = "0.1.0";
  src = ./.;

  nativeBuildInputs = [ pkgs.odin ];

  buildPhase = ''
    runHook preBuild
    odin build sysstat.odin -file -out:sysstat -o:speed -no-bounds-check -disable-assert
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp sysstat $out/bin
    runHook postInstall
  '';
}
