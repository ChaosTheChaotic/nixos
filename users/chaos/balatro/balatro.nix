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
		../../../modules/balatro.nix
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
    };
  };
}
