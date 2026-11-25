{
  config,
  lib,
  pkgs,
  userName,
  ...
}:

let
  # Nixpad hardware H.264 through VAAPI
  # NixyPenguin no VAAPI encoder, so software x264 on a linear scanout buffer
  defaultPipe = if pkgs.stdenv.hostPlatform.isx86_64 then "vaapi" else "cpu";

  ffmpegKms = "/run/wrappers/bin/ffmpeg-kms";

  scr = pkgs.writeShellApplication {
    name = "scr";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      util-linux # setsid
    ];
    # Env defaults; SCR_* variables set by you at runtime take priority
    runtimeEnv = {
      SCR_FFMPEG_DEFAULT = ffmpegKms;
      SCR_DEFAULT_PIPE = defaultPipe;
      SCR_HOME = config.users.users.${userName}.home;
    };
    excludeShellChecks = [ "SC2155" ];
    text = builtins.readFile ./scr.sh;
  };

  ttyOnly = pkgs.writeShellScript "scr-tty-only" ''
    sid=$(${pkgs.systemd}/bin/loginctl show-seat seat0 -p ActiveSession --value 2>/dev/null)
    if [ -n "$sid" ]; then
      type=$(${pkgs.systemd}/bin/loginctl show-session "$sid" -p Type --value 2>/dev/null)
      case "$type" in
        wayland|x11|mir) exit 0 ;;
      esac
    fi
    exec "$@"
  '';
in
{
  # kmsgrab needs CAP_SYS_ADMIN (or DRM master). Give it to one wrapped ffmpeg that only
  # members of screencap can execute, instead of making ffmpeg setcap for everyone
  users.groups.screencap = { };
  users.users.${userName}.extraGroups = [ "screencap" ];

  security.wrappers.ffmpeg-kms = {
    source = lib.getExe pkgs.ffmpeg;
    capabilities = "cap_sys_admin+ep";
    owner = "root";
    group = "screencap";
    permissions = "u+rx,g+x,o-rwx";
  };

  environment.systemPackages = [
    scr
    pkgs.drm_info # inspect planes/CRTCs/modifiers
    pkgs.libva-utils # vainfo, confirm H.264 encode entrypoint
  ];

  # Global hotkeys that work on any VT
  # Reads evdev directly
  # NOTE: Avoid Alt+SysRq, that is the kernels Magic SysRq combo
  services.triggerhappy = {
    enable = true;
    user = userName;
    bindings = [
      {
        keys = [
          "S"
          "LEFTMETA"
          "LEFTSHIFT"
        ];
        event = "press";
        cmd = "${ttyOnly} ${scr}/bin/scr shot";
      }
      {
        keys = [
          "R"
          "LEFTMETA"
          "LEFTSHIFT"
        ];
        event = "press";
        cmd = "${ttyOnly} ${scr}/bin/scr rec toggle";
      }
    ];
  };
  systemd.services.triggerhappy.serviceConfig.SupplementaryGroups = [
    "input"
    "video"
    "render"
    "screencap"
  ];
}
