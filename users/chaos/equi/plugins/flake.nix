{
  description = "Equicord userplugins bundle";

  inputs = {
    nixcord.url = "github:4evy/nixcord";
    eval = {
      url = "git+https://git.nin0.dev/userplugins/eval";
      flake = false;
    };
    venfetch = {
      url = "git+https://git.nin0.dev/userplugins/venfetch";
      flake = false;
    };
    clientsidebadges = {
      url = "git+https://git.nin0.dev/userplugins/clientsidebadges";
      flake = false;
    };
    gallerymode = {
      url = "github:Sodroz/GalleryMode";
      flake = false;
    };
    newlinesincommands = {
      url = "github:lolsuffocate/vc-NewlinesInCommands";
      flake = false;
    };
    inrole = {
      url = "git+https://git.nin0.dev/userplugins/in-role";
      flake = false;
    };
  };

  outputs =
    { nixcord, ... }@inputs:
    {
      inherit nixcord;
      plugins = inputs;
    };
}
