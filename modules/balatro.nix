{
  config,
  lib,
  pkgs,
  options,
  ...
}:

let
  cfg = config.programs.balatro;

  checkIsURL =
    str:
    (builtins.match "^[a-zA-Z][a-zA-Z0-9+.-]*://.*" str) != null
    || (builtins.match "^[a-zA-Z][a-zA-Z0-9+.-]*:.*/.*" str) != null;

	checkURLHasHash = url:
		if (builtins.match ".*([a-fA-F0-9]{40}|narHash=|sha256=).*" url) != null then true else false;

	fetchSafe = url:
		if !checkIsURL url then
			url
		else if !checkURLHasHash url then
			builtins.trace ''
      Failed to fetch "${url}"
      
      This error usually happens because either:
      
        1. The URL is a git repo and has no hash provided
          If the link provided looked something like "github:owner/repo" or "git+https://something.whatever/owner/repo"
          Nix will refuse to fetch it without a hash.
          The fix normally looks something like "github:owner/repo/hash" or "git+https://something.whatever/owner/repo/hash"
      
        2. The URL is some kind of archive
          The URL here also has no file hash, and thus nix will refuse to fetch it.
          The fix is either to use a nix fetcher (e.g pkgs.fetchzip) and give it a hash
          The hash will be given after initially running it and getting the hash it errors with
          Or to add "?narHash=..." to the end of the URL, and adding the hash after it errors.
      
      Note that there are other causes for this error, though the 2 listed above are the most likely.
      Additionally the error messages from this tool can be misleading.
      For your debugging purposes, the actual error follows.
			'' ((fetchTree url).outPath)
		else (fetchTree url).outPath;

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
      src = mod.src;

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

  checkModsTool = pkgs.writers.writePython3Bin "check-balatro-mods" { } (
    builtins.readFile ./check_mods.py
  );

  balatroModsDir = pkgs.symlinkJoin {
    name = "balatro-mods-dir";
    paths = map mkMod cfg.mods.modList;
    nativeBuildInputs = lib.optional cfg.mods.doMetaChecks checkModsTool;

    postBuild = lib.optionalString cfg.mods.doMetaChecks ''
			check-balatro-mods "$out"
		'';
  };

  moddedBalatroPkg = pkgs.symlinkJoin {
    name = "balatro-modded";
    paths = [ balatroPkg ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      ${lib.optionalString cfg.mods.enable ''
        wrapProgram $out/bin/balatro \
          --run 'export LOVELY_MOD_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/balatro/nix-mods"' \
          --run 'if [ "$(cat "$LOVELY_MOD_DIR/.nix-mods-version" 2>/dev/null)" != "${balatroModsDir}" ]; then
            ${pkgs.coreutils}/bin/rm -rf "$LOVELY_MOD_DIR"
            ${pkgs.coreutils}/bin/mkdir -p "$LOVELY_MOD_DIR"
            ${pkgs.coreutils}/bin/cp -rL --no-preserve=mode,ownership "${balatroModsDir}/." "$LOVELY_MOD_DIR/" 2>/dev/null || true
            ${pkgs.findutils}/bin/find "$LOVELY_MOD_DIR" -type d -exec ${pkgs.coreutils}/bin/chmod u+w {} +
            echo "${balatroModsDir}" > "$LOVELY_MOD_DIR/.nix-mods-version"
          fi'
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
      type = lib.types.nullOr (lib.types.coercedTo lib.types.str fetchSafe lib.types.path);
      default = null;
      description = "The src attribute to override, or a URL to fetch";
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

          doMetaChecks = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Sets if metadata checks should be done, erroring if conflicts or missed dependencies are found.";
          };

          modList = lib.mkOption {
            description = "The list of mods to add";
            default = [ ];
            type = lib.types.listOf (
              lib.types.coercedTo lib.types.path
                (p: {
                  src = p;
                  enabled = true;
                  name = null;
                  patches = [ ];
                })
                (
                  lib.types.submodule (
                    { ... }: {
                      options = {
                        src = lib.mkOption {
                          type = lib.types.coercedTo lib.types.str fetchSafe lib.types.path;
                          description = "Path to the mod folder, or a URL to fetch";
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
              mod: if mod.name != null then mod.name else baseNameOf mod.src
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
