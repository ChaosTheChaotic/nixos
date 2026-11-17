{
  lib,
  stdenvNoCC,
  p7zip,
  requireFile,
  balatroExe ? null,
}:

stdenvNoCC.mkDerivation {
  pname = "decomlatro";
  version = "unstable";

  src =
    if balatroExe != null then
      balatroExe
    else
      requireFile {
        name = "Balatro.exe";
        url = "https://store.steampowered.com/app/2379780/Balatro/";
        message = ''
          You must provide a balatro executable file in the way that pkgs.balatro expects it to use its sources for the LSP
        '';
        # Use `nix --extra-experimental-features nix-command hash file --sri --type sha256` to get the correct hash
        hash = "sha256-DXX+FkrM8zEnNNSzesmHiN0V8Ljk+buLf5DE5Z3pP0c=";
      };
  dontUnpack = true;

  nativeBuildInputs = [ p7zip ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    7z x -y -o"$out" "$src"
    runHook postInstall
  '';

  meta = {
    description = "Unpacked Balatro Lua sources for language-server use";
    license = lib.licenses.unfree;
  };
}
