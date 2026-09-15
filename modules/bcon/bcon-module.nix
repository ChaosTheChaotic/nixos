{
  pkgs,
  lib,
  bconSrc ? null,
  ...
}:

let
  bcon = pkgs.callPackage ./bcon.nix { bconSrc = bconSrc; };

  bconTty = "tty2";

  graphicsLibs = lib.makeLibraryPath [
    pkgs.libglvnd
    pkgs.mesa
    pkgs.libGL
  ];
in
{
  environment.systemPackages = [ bcon ];

  # bcon needs GPU/EGL access
  hardware.graphics.enable = true;

  # Mask getty so it cannot race with bcon i.e if other programs spawn getty etc.
  systemd.services."getty@${bconTty}".enable = false;

  systemd.services."bcon@${bconTty}" = {
    description = "bcon terminal emulator on %I";
    documentation = [ "https://github.com/sanohiro/bcon" ];

    after = [
      "systemd-user-sessions.service"
      "plymouth-quit-wait.service"
      "rc-local.service"
    ];
    before = [ "getty@%i.service" ];
    conflicts = [ "getty@%i.service" ];
    wantedBy = [ "multi-user.target" ];

    unitConfig = {
      ConditionPathExists = "/dev/%I";
    };

    environment = {
      BCON_BACKEND = "vt";
      RUST_LOG = "info";
      LD_LIBRARY_PATH = graphicsLibs;
    };

    serviceConfig = {
      Type = "simple";
      ExecStart = "${bcon}/bin/bcon";
      WorkingDirectory = "/root";

      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal";

      TTYPath = "/dev/%I";
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;

      Restart = "always";
      RestartSec = 1;

      LimitNOFILE = 65535;

      CapabilityBoundingSet = [
        "CAP_SYS_TTY_CONFIG"
        "CAP_SYS_ADMIN"
        "CAP_SETUID"
        "CAP_SETGID"
        "CAP_SETPCAP"
        "CAP_DAC_OVERRIDE"
        "CAP_AUDIT_WRITE"
        "CAP_CHOWN"
        "CAP_FOWNER"
        "CAP_SYS_RESOURCE"
      ];
      AmbientCapabilities = [ "CAP_SYS_TTY_CONFIG" ];
    };
  };
}
