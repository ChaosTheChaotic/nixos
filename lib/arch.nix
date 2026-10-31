{
  lib,
  cpuArch,
  isAarch64,
}:
let
  isArch = cpuArch != "generic";
  march = if isAarch64 then "-mcpu" else "-march";
in
rec {
  nixCflags = lib.optionalString isArch " ${march}=${cpuArch} -O3";
  rustFlags = lib.optionalString isArch "-C target-cpu=${cpuArch} -C llvm-args=-vectorize-loops";
  zigTarget = if isArch then cpuArch else "baseline";
  mesonCflags = lib.optionals isArch [
    "-Dc_args=${march}=${cpuArch}"
    "-Dcpp_args=${march}=${cpuArch}"
  ];
  withRustFlags =
    drv:
    drv.overrideAttrs (old: {
      env = (old.env or { }) // lib.optionalAttrs (rustFlags != "") { RUSTFLAGS = rustFlags; };
    });

  withCflags =
    drv:
    drv.overrideAttrs (old: {
      NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + nixCflags;
    });
  withAll =
    drv:
    lib.pipe drv [
      withCflags
      withRustFlags
    ];
}
