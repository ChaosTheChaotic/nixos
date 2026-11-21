# Personal yacht glue (goes in your nixos config repo)

Copy `modules/yacht-bcon/` into your config (next to `modules/bcon`), then:

## hosts/common.nix

```nix
imports = [ ../modules/yacht-bcon ];   # or add to your existing imports

programs.yacht.enable = true;          # you already have this
services.yacht-bcon.enable = true;

# fbb: wrap your EXISTING package expression, nothing else changes
programs.framebuffer-browser.package =
  inputs.yacht.lib.wrapQtApp pkgs {
    package = /* whatever you had here, e.g. ccache.withCcache pkgs (inputs.fbb.packages.${pkgs.stdenv.hostPlatform.system}.default) */;
  };
```

`wrapQtApp` takes the binary name from the package's `meta.mainProgram`
(`fbbrowser`); pass `bin = "fbbrowser";` if it doesn't. The Qt bridge labels
entries with the app's executable name, so they show up as source `fbbrowser`.
Your flake already has `inputs.fbb.inputs.nixpkgs.follows = "nixpkgs"`, which is
what keeps the plugin's Qt and the browser's Qt identical.

## users/chaos/home.nix

```nix
programs.yacht.enable = true;     # you already have this
```

Don't enable `programs.yacht.ttyWrap` under bcon: the bcon service above already
sees every copy, and fbb's file-chooser shell would need
`ttyWrapSkipIfSet = [ "YIELD_SHELL_PID" ];` if you ever did.

## nvim (nixvim)

`extraConfigLua = builtins.readFile ./yacht.lua;` with the contents of
`contrib/nvim.lua` from the yacht repo.

## Verify

```sh
systemctl --user status yachtd yacht-bcon yacht-watch
QT_DEBUG_PLUGINS=1 fbbrowser 2>&1 | grep -i yacht       # plugin loaded (Qt versions match)
yacht list                                              # sources: bcon, fbbrowser, wayland, ...
```
