{ config, ... }:
let
  home = config.users.users.chaos.home;
  devices = {
    asahi = {
      id = "MTI5TFN-XS65Z6U-GYCD6OB-J6QVCC2-KB2OJIX-RRSWGNG-JH6OFSM-3N5XRAA";
      addresses = [ "tcp://10.199.185.187" ];
    };
    nixpad = {
      id = "HQV3VEG-ESIF7KR-J6L7KGN-L4G7JKU-42XZPCW-DALIVYV-PR7UBFE-V2QVJQ2";
      addresses = [ "tcp://10.199.185.151" ];
    };
  };
  all = builtins.attrNames devices;
in
{
  age.secrets.syncthing-key = {
    owner = "chaos";
    mode = "0400";
  };

  services.syncthing = {
    enable = true;
    openDefaultPorts = false;
    user = "chaos";
    group = "users";
    dataDir = home;
    configDir = "${home}/.config/syncthing";
    key = config.age.secrets.syncthing-key.path;
    overrideFolders = true;
    overrideDevices = true;

    settings = {
      options = {
        globalAnnounceEnabled = false;
        localAnnounceEnabled = false;
        relaysEnabled = false;
        natEnabled = false;
        urAccepted = -1;
        crashReportingEnabled = false;
        startBrowser = false;
        listenAddresses = [ "tcp://0.0.0.0:22000" ];
      };

      inherit devices;

      folders = {
        music = {
          path = "${home}/Music";
          devices = all;
          type = "sendreceive";
          fsWatcherEnabled = true;
          versioning = {
            type = "trashcan";
            params.cleanoutDays = "30";
          };
        };
      };
    };
  };

  networking.firewall.interfaces."zt+".allowedTCPPorts = [ 22000 ];
}
