{
  pkgs,
  lib,
  inputs,
  cpuArch ? "generic",
  master,
  ...
}:

{
  imports = [
    inputs.balatro.balanix.homeManagerModules.default
  ];

  programs.balatro = {
    enable = true;
    package = master.balatro;
    src-path = null;
    mods = {
      enable = true;
      lovely-injector-package = pkgs.rustPlatform.buildRustPackage rec {
        pname = "lovely-injector";
        version = "0.9.0";

        src = pkgs.fetchFromGitHub {
          owner = "ethangreen-dev";
          repo = "lovely-injector";
          rev = "v${version}";
          hash = "sha256-TzBxyIf7MjzsdFaJLBp2dXWNj5sOXyoMifaaztNIOog=";
          fetchSubmodules = true;
        };

        cargoLock = {
          lockFile = "${inputs.lovely-injector}/Cargo.lock";
          outputHashes."retour-0.4.0-alpha.2" = "sha256-GtLTjErXJIYXQaOFLfMgXb8N+oyHNXGTBD0UeyvbjrA=";
        };

        cargoBuildFlags = [
          "--package"
          "lovely-unix"
        ];
        doCheck = false;
        env = {
          RUSTC_BOOTSTRAP = "1";
        }
        // (lib.optionalAttrs (cpuArch != "generic") {
          RUSTFLAGS = "-C target-cpu=${cpuArch} -C llvm-args=-vectorize-loops";
        });
        nativeBuildInputs = [ pkgs.cmake ];
      };
      modList =
        let

          disabledMods = [
            "Solatro"
          ];

          patchMap = {
            "BalatroMultiplayer" = [
              {
                file = "ui/game/round.lua";
                regex = "MP\\.UTILS\\.log_mem_debug_messages.*$";
                replace = "MP.UTILS.log_mem_debug_messages()\n\t\treturn";
              }
              {
                file = "lib/matchmaking.lua";
                regex = "if not mod\\.disabled and key ~= \"Balatro\" then table\\.insert\\(mod_table, key \\.\\. \"-\" \\.\\. \\(mod\\.version or \"UNK\"\\)\\) end";
                replace = "if not mod.disabled and key == \"Multiplayer\" then table.insert(mod_table, key .. \"-\" .. (mod.version or \"UNK\")) end";
              }
              {
                file = "core.lua";
                regex = "MP\\.BANNED_MODS = \\{[^\\}]*\\}";
                replace = "MP.BANNED_MODS = {}";
              }
            ];
          };

          addPrefs = modName: modPath: {
            src = modPath;
            name = modName;
            enabled = !(builtins.elem (lib.toLower modName) (map lib.toLower disabledMods));
            patches = if patchMap ? ${modName} then patchMap.${modName} else [ ];
          };
        in
        lib.mapAttrsToList addPrefs inputs.balatro.modding.mods;
    };
  };
}
