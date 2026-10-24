{
  pkgs,
  ...
}:

let
  sysstat = pkgs.callPackage ../../pkgs/sysstat/sysstat.nix { };
in
{
  systemd.user.services.sysstat = {
    Unit.Description = "System statistics daemon";
    Service = {
      ExecStart = "${sysstat}/bin/sysstat";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
