{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  qt6,
  runtimeShell,
  coreutils,
  util-linux,
  defaultBackend ? "auto",
}:

assert lib.assertOneOf "defaultBackend" defaultBackend [
  "auto"
  "eglfs"
  "fb"
];

stdenv.mkDerivation {
  pname = "framebuffer-browser";
  version = "0-unstable";

  src = fetchFromGitHub {
    owner = "femelo";
    repo = "framebuffer-browser";
    rev = "main";
    hash = "sha256-Y0M0KO9JuyoZ7BkXWHEySf39/ajPLPL7611WYbaF7HI=";
  };

  nativeBuildInputs = [
    cmake
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtwebengine
  ];

  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail 'set(CMAKE_PREFIX_PATH /opt/qt6.8/6.8.0/gcc_64)' ""
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 fbbrowser $out/libexec/fbbrowser/fbbrowser

    install -Dm755 ${./launcher.sh} $out/bin/fbbrowser
    substituteInPlace $out/bin/fbbrowser \
      --subst-var-by shell ${runtimeShell} \
      --subst-var-by path ${lib.makeBinPath [ coreutils util-linux ]} \
      --subst-var-by unwrapped $out/libexec/fbbrowser/fbbrowser \
      --subst-var-by defaultBackend ${defaultBackend}

    runHook postInstall
  '';

	# Launcher is shell script, only real binary gets wrapped
  dontWrapQtApps = true;
  postFixup = ''
    wrapQtApp $out/libexec/fbbrowser/fbbrowser
  '';

  meta = {
    description = "Minimal QtWebEngine (Qt6) web browser for the Linux framebuffer / KMS, no X11 or Wayland needed";
    homepage = "https://github.com/femelo/framebuffer-browser";
    license = lib.licenses.lgpl3Only;
    mainProgram = "fbbrowser";
    platforms = lib.intersectLists lib.platforms.linux qt6.qtwebengine.meta.platforms;
  };
}
