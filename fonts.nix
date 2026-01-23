{
  stdenvNoCC,
  lib,
  findutils,
}:

stdenvNoCC.mkDerivation {
  pname = "extra-fonts";
  version = "1.0";

  src = ./fonts;

  nativeBuildInputs = [ findutils ];

  installPhase = ''
    mkdir -p $out/share/fonts/truetype

    # Find all .ttf and .otf files recursively and copy them
    find $src -type f \( -iname '*.ttf' -o -iname '*.otf' \) -exec install -m444 -Dt $out/share/fonts/truetype {} +
  '';

  meta = with lib; {
    description = "Extra fonts";
    homepage = "";
    platforms = platforms.all;
    maintainers = with maintainers; [ ];
  };
}
