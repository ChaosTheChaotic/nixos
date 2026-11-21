# Personal glue: bcon -> yacht. Lives in the system config, not in the yacht repo.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.yacht-bcon;
  script = pkgs.writeShellApplication {
    name = "yacht-bcon";
    runtimeInputs = [
      pkgs.inotify-tools
      pkgs.coreutils
      config.programs.yacht.package
    ];
    text = builtins.readFile ./yacht-bcon.sh;
  };
in
{
  options.services.yacht-bcon.enable = lib.mkEnableOption "mirroring bcon's clipboard into yacht";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.programs.yacht.enable;
        message = "services.yacht-bcon needs programs.yacht.enable (it uses that package).";
      }
    ];
    # A NixOS-level *user* unit: runs in every user's login manager, TTY or not.
    systemd.user.services.yacht-bcon = {
      description = "Mirror bcon's clipboard into yacht";
      after = [ "yachtd.service" ];
      wants = [ "yachtd.service" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = lib.getExe script;
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
