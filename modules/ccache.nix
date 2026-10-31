{
  config,
  pkgs,
  ccache,
  ...
}:

let
  cfg = config.programs.ccache;
  dir = toString cfg.cacheDir;
in
{
  programs.ccache = {
    enable = true;
    cacheDir = ccache.cacheDir;

    # Keep packageNames empty as it only handles top level stuff and it rewrites every name listed
    # Naming a package that is binary cached in remote would make it into a local build
    # Nixpkgs only configures ccache wrapper when list is nonempty so we configure it outselves via ccache.overlay
  };

  environment.systemPackages = [ pkgs.ccache ];

  nix.settings.extra-sandbox-paths = [ dir ];

  nixpkgs.overlays = [ ccache.overlay ];

  # Kept as a real file (not a store symlink) because the sandbox only sees ${dir}, not arbitrary store paths.
  system.activationScripts.ccacheConf = ''
    ${pkgs.coreutils}/bin/install -d -m 0775 -o ${cfg.owner} -g ${cfg.group} ${dir}
    ${pkgs.coreutils}/bin/install -D -m 0664 -o ${cfg.owner} -g ${cfg.group} \
      ${pkgs.writeText "ccache.conf" ccache.confText} ${dir}/ccache.conf
  '';
}
