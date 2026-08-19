{
  config,
  lib,
  pkgs,
  options,
  ...
}:

let
  cfg = config.programs.balatro;

  basePkg = cfg.package.override {
    withBridgePatch = cfg.bridgePatch;
    withLinuxPatch = cfg.linuxPatch;
    withMods = cfg.mods.enable;
    love = cfg.love-package;
    lovely-injector = cfg.mods.lovely-injector-package;
  };
  balatroPkg =
    if cfg.src-path != null then
      basePkg.overrideAttrs (old: {
        src = cfg.src-path;
      })
    else
      basePkg;

  mkPatchCmd =
    p:
    if p.patch != null then
      ''
        patch -p1 < ${p.patch}
      ''
    else
      ''
        FIND=${lib.escapeShellArg p.regex} REPLACE=${lib.escapeShellArg p.replace} awk '
          BEGIN {
            find = ENVIRON["FIND"];
            repl = ENVIRON["REPLACE"];
            gsub(/\\/, "\\\\", repl);
            gsub(/&/, "\\&", repl);
            RS = "\0";
          }
          { gsub(find, repl) }
          1
        ' "${p.file}" > "${p.file}.tmp"
        mv "${p.file}.tmp" "${p.file}"
      '';

  mkMod =
    mod:
    let
      modName = if mod.name != null then mod.name else baseNameOf mod.path;
    in
    pkgs.stdenv.mkDerivation {
      name = "balatro-mod-${lib.strings.sanitizeDerivationName modName}";
      src = mod.path;

      dontBuild = true;
      dontConfigure = true;

      postPatch = lib.concatMapStringsSep "\n" mkPatchCmd mod.patches;

      installPhase = ''
        runHook preInstall

        mkdir -p "$out/${modName}"
        cp -rT . "$out/${modName}/"

        ${lib.optionalString (!mod.enabled) ''
          touch $out/${modName}/.lovelyignore
        ''}

        runHook postInstall
      '';
    };

  balatroModsDir = pkgs.symlinkJoin {
    name = "balatro-mods-dir";
    paths = map mkMod cfg.mods.modList;
  };

  moddedBalatroPkg = pkgs.symlinkJoin {
    name = "balatro-modded";
    paths = [ balatroPkg ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      ${lib.optionalString cfg.mods.enable ''
        wrapProgram $out/bin/balatro \
          --run 'export LOVELY_MOD_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/balatro/nix-mods"' \
          --run 'mkdir -p "$LOVELY_MOD_DIR"' \
          --run '${pkgs.findutils}/bin/find "$LOVELY_MOD_DIR" -type l -delete' \
          --run '${pkgs.coreutils}/bin/cp -rs "${balatroModsDir}/." "$LOVELY_MOD_DIR/" 2>/dev/null || true' \
          --run '${pkgs.findutils}/bin/find "$LOVELY_MOD_DIR" -type d -exec ${pkgs.coreutils}/bin/chmod u+w {} +'
      ''}
    '';
  };

  installBalatroPkg = if cfg.mods.enable then moddedBalatroPkg else balatroPkg;
in
{
  options.programs.balatro = {
    enable = lib.mkEnableOption "Poker Roguelike";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.balatro;
      description = "Balatro package to use";
    };
    love-package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.love;
      description = "The love package to use";
    };
    bridgePatch = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the bridge patch";
    };
    linuxPatch = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the linux patch";
    };
    src-path = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "The src attribute to override in nixpkgs balatro.nix";
    };
    mods = lib.mkOption {
      description = "Settings for Balatro modding.";
      default = { };
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "Enable mods for balatro";

          lovely-injector-package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.lovely-injector;
            description = "Lovely-injector package to use";
          };

          modList = lib.mkOption {
            description = "The list of mods to add";
            default = [ ];
            type = lib.types.listOf (
              lib.types.coercedTo lib.types.path
                (p: {
                  path = p;
                  enabled = true;
                  name = null;
                  patches = [ ];
                })
                (
                  lib.types.submodule (
                    { ... }: {
                      options = {
                        path = lib.mkOption {
                          type = lib.types.path;
                          description = "Path to the mod folder";
                        };
                        enabled = lib.mkOption {
                          type = lib.types.bool;
                          default = true;
                          description = "If the mod should be enabled or not";
                        };
                        name = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = "Optional override for the name of the folder containing the mod";
                        };
                        patches = lib.mkOption {
                          type = lib.types.listOf (
                            lib.types.coercedTo lib.types.path
                              (p: {
                                patch = p;
                                file = null;
                                regex = null;
                                replace = null;
                              })
                              (
                                lib.types.submodule {
                                  options = {
                                    patch = lib.mkOption {
                                      type = lib.types.nullOr lib.types.path;
                                      default = null;
                                      description = "Path to the -p1 .patch file to be applied";
                                    };
                                    file = lib.mkOption {
                                      type = lib.types.nullOr lib.types.str;
                                      default = null;
                                      description = "Path to the file to run the find replace patch on, relative to the mod root";
                                    };
                                    regex = lib.mkOption {
                                      type = lib.types.nullOr lib.types.str;
                                      default = null;
                                      description = "The extended regex pattern to search for";
                                    };
                                    replace = lib.mkOption {
                                      type = lib.types.nullOr lib.types.str;
                                      default = null;
                                      description = "The text to replace the regex match with";
                                    };
                                  };
                                }
                              )
                          );
                        };
                      };
                    }
                  )
                )
            );
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [

      (lib.optionalAttrs (options ? environment) {
        environment.systemPackages = [
          installBalatroPkg
        ];
      })

      (lib.optionalAttrs (options ? home) {
        home.packages = [
          installBalatroPkg
        ];
      })

      {
        assertions =
          let
            modDirNames = map (
              mod: if mod.name != null then mod.name else baseNameOf mod.path
            ) cfg.mods.modList;

            countOccurrences = item: list: builtins.length (builtins.filter (x: x == item) list);

            duplicateNames = lib.lists.unique (
              builtins.filter (name: (countOccurrences name modDirNames) > 1) modDirNames
            );

            hasNoDuplicates = builtins.length duplicateNames == 0;

            allPatches = lib.flatten (map (mod: mod.patches) cfg.mods.modList);

            isPatchValid =
              p:
              (p.patch != null && p.file == null && p.regex == null && p.replace == null)
              || (p.patch == null && p.file != null && p.regex != null && p.replace != null);

            invalidPatches = builtins.filter (p: !isPatchValid p) allPatches;
          in
          [
            {
              assertion = !cfg.mods.enable || hasNoDuplicates;
              message = ''
                Duplicate mod directory identifiers are disallowed.
                The following mod directory identifiers are duplicated:
                ${lib.concatMapStringsSep "\n" (name: "  - ${name}") duplicateNames}
              '';
            }
            {
              assertion = builtins.length invalidPatches == 0;
              message = "Balatro mod patches must provide either a 'patch' OR a 'file', 'regex', and 'replace' set.";
            }
          ];
      }
    ]
  );
}
