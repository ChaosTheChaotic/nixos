{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    genAttrs
    literalExpression
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  cfg = config.programs.bcon;

  tomlFormat = pkgs.formats.toml { };
  configFile = tomlFormat.generate "bcon-config.toml" cfg.settings;

  autoVTs = lib.toInt (toString (config.services.logind.settings.Login.NAutoVTs or 6));

  activeTtys =
    if cfg.ttys == "all" then
      map (n: "tty${toString n}") (lib.range 1 autoVTs)
    else
      lib.unique cfg.ttys;

  # bcon dlopens EGL/GLES at runtime
  graphicsLibs = lib.makeLibraryPath [
    pkgs.libglvnd
    pkgs.mesa
    pkgs.libGL
  ];
in
{
  options.programs.bcon = {
    enable = mkEnableOption "bcon, a GPU-accelerated terminal emulator for the Linux console";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./bcon.nix { bconSrc = cfg.src; };
      defaultText = literalExpression "pkgs.callPackage ./bcon.nix { bconSrc = config.programs.bcon.src; }";
      description = "The bcon package to run.";
    };

    src = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = literalExpression "inputs.bcon";
      description = "Source tree to build bcon from.";
    };

    ttys = mkOption {
      type = types.either (types.enum [ "all" ]) (types.listOf (types.strMatching "tty[0-9]+"));
      default = [ "tty2" ];
      example = [
        "tty2"
        "tty3"
      ];
      description = ''
        Virtual terminals bcon takes over. Either a list of tty names, or
        `"all"` for tty1 (inclusive) up to logind's `NAutoVTs` (6 by default).
      '';
    };

    settings = mkOption {
      type = tomlFormat.type;
      default = { };
      example = literalExpression ''
        {
          font = {
            main = "JetBrainsMono Nerd Font Mono";
            emoji = "Noto Color Emoji";
            size = 18.0;
          };
          terminal.scrollback_lines = 20000;
        }
      '';
      description = ''
        Contents of `/etc/bcon/config.toml`
        See <https://github.com/sanohiro/bcon/blob/main/docs/configuration.md>
        for the available keys.      '';
    };

    logLevel = mkOption {
      type = types.str;
      default = "info";
      example = "debug";
      description = "Value of `RUST_LOG` for the bcon services.";
    };

    extraEnvironment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        BCON_BACKEND = "vt";
      };
      description = "Extra environment variables for the bcon services. Merged over the module's defaults.";
    };

    polkitPowerRules = mkEnableOption ''
      a polkit rule letting members of `wheel` reboot, power off and inhibit
      the lid switch from a bcon session
    '';

    disableBluezSeatMonitoring = mkEnableOption ''
      disabling WirePlumber's Bluetooth seat monitoring so Bluetooth audio
      keeps working from a bcon session
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = activeTtys != [ ];
          message = "programs.bcon.ttys must list at least one tty (or be \"all\").";
        }
      ];

      environment.systemPackages = [ cfg.package ];

      environment.etc = mkIf (cfg.settings != { }) {
        "bcon/config.toml".source = configFile;
      };

      # bcon needs GPU/EGL access
      hardware.graphics.enable = mkDefault true;

      systemd.services = {
        "bcon@" = {
          description = "bcon terminal emulator on %I";
          documentation = [ "https://github.com/sanohiro/bcon" ];

          path = [ pkgs.fontconfig ];

          after = [
            "systemd-user-sessions.service"
            "plymouth-quit-wait.service"
            "rc-local.service"
          ];
          before = [ "getty@%i.service" ];
          conflicts = [ "getty@%i.service" ];

          unitConfig.ConditionPathExists = "/dev/%I";

          environment = {
            BCON_BACKEND = "vt";
            RUST_LOG = cfg.logLevel;
            LD_LIBRARY_PATH = graphicsLibs;
          }
          // cfg.extraEnvironment;

          restartIfChanged = false;

          serviceConfig = {
            Type = "simple";
            ExecStart = lib.getExe cfg.package;
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
      // genAttrs (map (tty: "getty@${tty}") activeTtys) (_: {
        enable = false;
      });

      systemd.targets.multi-user.wants = map (tty: "bcon@${tty}.service") activeTtys;
    }

    (mkIf cfg.disableBluezSeatMonitoring {
      environment.etc."wireplumber/wireplumber.conf.d/51-disable-bluez-seat-monitoring.conf".text = ''
        wireplumber.profiles = {
          main = {
            monitor.bluez.seat-monitoring = disabled
          }
        }
      '';
    })

    (mkIf cfg.polkitPowerRules {
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          var allowed = [
            "org.freedesktop.login1.reboot",
            "org.freedesktop.login1.reboot-multiple-sessions",
            "org.freedesktop.login1.power-off",
            "org.freedesktop.login1.power-off-multiple-sessions",
            "org.freedesktop.login1.inhibit-handle-lid-switch"
          ];
          if (subject.isInGroup("wheel") && allowed.indexOf(action.id) >= 0) {
            return polkit.Result.YES;
          }
        });
      '';
    })
  ]);
}
