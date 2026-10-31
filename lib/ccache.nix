# In any module that receives this argument, ccache means this attrset
# Package is pkgs.ccache
{
  lib,
  enable ? false,
  cacheDir ? "/var/cache/ccache",
  # Applies to the compressed size on disk
  maxSize ? "10G",
  # zstd level. Higher = smaller cache, slightly slower stores
  # Reads (cache hits) decompress at the same speed at every level
  compressionLevel ? 5,
}:

let
  # Written to ${cacheDir}/ccache.conf
  # Deliberately not part of the wrappers extraConfig below as changing a value here never changes a derivation hash
  # Tuning the cache cant trigger a rebuild
  confText =
    lib.concatStringsSep "\n" [
      "max_size = ${maxSize}"
      "umask = 007"
      "compression = true"
      "compression_level = ${toString compressionLevel}"
      # nixpkgs cc-wrapper injects -frandom-seed=<derivation hash>. Unless ccache
      # ignores it, every derivation change is a guaranteed cache miss
      "sloppiness = random_seed"
      "compiler_check = content"
    ]
    + "\n";

  # Shared by the stdenv wrapper (runs before every compile) and withCmakeLauncher (runs once at configure time)
  envSetup = ''
    export CCACHE_DIR=${lib.escapeShellArg cacheDir}
    if [ ! -w "$CCACHE_DIR" ]; then
      echo "ccache: $CCACHE_DIR is missing or not writable inside this build." >&2
      echo "ccache: check nix.settings.extra-sandbox-paths and that the running nix-daemon has picked it up." >&2
      echo "ccache: falling back to uncached compilation for this build." >&2
      export CCACHE_DISABLE=1
    fi
  '';

  overlay = _final: prev: {
    ccacheWrapper = prev.ccacheWrapper.override { extraConfig = envSetup; };
    # Marker so wrapStdenv can refuse a nixpkgs instance that never got this overlay
    ccacheOverlayApplied = true;
  };

  # Wrap any stdenv so its compiler goes through ccache
  # pkgs must be a nixpkgs instance that has overlay applied
  wrapStdenv =
    pkgs: base:
    if enable then
      assert lib.assertMsg (pkgs.ccacheOverlayApplied or false)
        "ccache: this nixpkgs instance was imported without ccache.overlay; builds would silently bypass the cache";
      pkgs.overrideCC base (pkgs.ccacheWrapper.override { cc = base.cc; })
    else
      base;

  stdenvFor = pkgs: wrapStdenv pkgs pkgs.stdenv;

  # For cmake pkgs which have stdenvs which cant be changed
  # Just tell cmake to run through ccache instead
  # Doesent touch the toolchain or the packages nixpkgs
  # Ccache sits outside the wrapper so flags the warpper injects arent part of the hash (contents of headers still are)
  withCmakeLauncher =
    pkgs: pkg:
    if enable then
      pkg.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.ccache ];
        cmakeFlags = (old.cmakeFlags or [ ]) ++ [
          "-DCMAKE_C_COMPILER_LAUNCHER=ccache"
          "-DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
        ];
        preConfigure = envSetup + (old.preConfigure or "");
      })
    else
      pkg;
in
{
  inherit
    enable
    cacheDir
    confText
    overlay
    wrapStdenv
    withCmakeLauncher
    ;

  # Default stdenv of pkgs ccache wrapped
  # Use for callPackge ./foo.nix { stdenv = ccache.stdenv pkgs; }
  stdenv = stdenvFor;

  # pkg.override { stdenv = <ccache-wrapped default stdenv of pkgs>; }.
  #   use for: packages whose function takes a plain stdenv argument.
  withCcache = pkgs: pkg: if enable then pkg.override { stdenv = stdenvFor pkgs; } else pkg;
}
