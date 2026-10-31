{
  pkgs,
  lib,
  config,
  ...
}:

let
  buildMozillaXpiAddon = pkgs.nur.repos.rycee.firefox-addons.buildFirefoxXpiAddon;
  vicinae-browser-integration = buildMozillaXpiAddon {
    pname = "vicinae-browser-integration";
    version = "1.0.0";
    addonId = "firefox@vicinae.com";
    urls = [
      "https://addons.mozilla.org/firefox/downloads/file/4839406/vicinae-1.0.0.xpi"
    ];
    sha256 = "sha256-mWwFbVVr6cnJdJRANnJGMReXPn0b/BD62fcZ+MB9lCY=";
    meta = with lib; {
      homepage = "https://www.vicinae.com";
      description = "Connects to the Vicinae desktop app to search and switch browser tabs from the launcher.";
      license = {
        shortName = "vicinae-browser-integration";
        fullName = "Vicinae Browser Integration";
        url = "https://addons.mozilla.org/en-US/firefox/addon/vicinae/license";
        free = true;
      };
      mozPermissions = [
        "nativeMessaging"
        "tabs"
      ];
      platforms = platforms.all;
    };
  };
in
{
  programs = {
    hyprlock.enable = true;
    floorp = {
      enable = true;
      nativeMessagingHosts = [ config.programs.vicinae.package ];
      profiles.default = {
        search = {
          force = true;
          default = "SearXNG";
          engines = {
            "SearXNG" = {
              urls = [
                {
                  template = "https://priv.au/search";
                  params = [
                    {
                      name = "q";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              icon = "https://priv.au/favicon.ico";
              definedAliases = [ "@sx" ];
            };
          };
        };
        extensions = {
          packages = with pkgs.nur.repos.rycee.firefox-addons; [
            ublock-origin
            return-youtube-dislikes
            sponsorblock
            vimium-c
            vicinae-browser-integration
          ];
        };
      };
    };
    cava.enable = true;
    kitty = {
      enable = true;
      enableGitIntegration = true;
      settings = {
        remember_window_size = "no";
        confirm_os_window_close = 0;
        dynamic_background_opacity = true;
        enable_audio_bell = false;
        background_opacity = "0.3";
        background_blur = 5;
        cursor_trail = 1;
        font_family = "JetBrains Mono Nerd Font";
        font_size = 8;
        bold_font = "auto";
        italic_font = "auto";
        bold_italic_font = "auto";
        window_padding_width = 4;
      };
    };
  };
}
