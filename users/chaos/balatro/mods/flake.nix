{
  description = "Balatro mods bundle";

  inputs = {
    Balatro-with-Multiverse-Time-Travel = {
      url = "github:Aluminumroadlion/5D-Balatro-with-Multiverse-Time-Travel";
      flake = false;
    };

    AllJokersChallenge = {
      url = "github:Sciman101/AllJokersChallenge";
      flake = false;
    };

    Balatro-ColoredSuitTarots = {
      url = "github:ywssp/Balatro-ColoredSuitTarots";
      flake = false;
    };

    balatrodarkmode = {
      url = "github:CarrotonMan/balatrodarkmode?dir=balatroDarkMode";
      flake = false;
    };

    Balatro-FortuneTeller = {
      url = "github:liafonx/Balatro-FortuneTeller";
      flake = false;
    };

    BalatroMultiplayer = {
      url = "github:Balatro-Multiplayer/BalatroMultiplayer";
      flake = false;
    };

    Balatro-Planet-Card-Cash-Out-Mod = {
      url = "github:antler5/Balatro-Planet-Card-Cash-Out-Mod";
      flake = false;
    };

    Balatro-Stickers-Always-Shown = {
      url = "github:SirMaiquis/Balatro-Stickers-Always-Shown";
      flake = false;
    };

    balatro-utils = {
      url = "git+https://codeberg.org/frostice482/balatro-utils";
      flake = false;
    };

    BetterTags = {
      url = "github:WaffleDevs/BetterTags";
      flake = false;
    };

    Blueprint = {
      url = "github:stupxd/Blueprint";
      flake = false;
    };

    Brainstorm = {
      url = "github:OceanRamen/Brainstorm";
      flake = false;
    };

    Cartomancer = {
      url = "github:stupxd/Cartomancer";
      flake = false;
    };

    CrystalBall = {
      url = "github:DylanMoss1/CrystalBall";
      flake = false;
    };

    DebugPlus = {
      url = "github:WilsontheWolf/DebugPlus";
      flake = false;
    };

    deselect-all-steamodded = {
      url = "github:Zei33/deselect-all-steamodded";
      flake = false;
    };

    DVPreview = {
      url = "git+https://github.com/DivvyCr/Balatro-Preview?submodules=1";
      flake = false;
    };

    Flower-Pot = {
      url = "github:GauntletGames-2086/Flower-Pot";
      flake = false;
    };

    Galdur = {
      url = "github:Eremel/Galdur";
      flake = false;
    };

    HandyBalatro = {
      url = "github:SleepyG11/HandyBalatro";
      flake = false;
    };

    JokerDisplay = {
      url = "github:nh6574/JokerDisplay";
      flake = false;
    };

    JokerSellValue = {
      url = "github:OppositeWolf770/JokerSellValue";
      flake = false;
    };

    lua_patcher = {
      url = "github:Piengineer12/lua_patcher";
      flake = false;
    };

    Malverk = {
      url = "github:Eremel/Malverk";
      flake = false;
    };

    next-ante-preview = {
      url = "github:DigitalDetective47/next-ante-preview";
      flake = false;
    };

    PlayLog = {
      url = "github:nh6574/PlayLog";
      flake = false;
    };

    potatro = {
      url = "github:balt-dev/potatro";
      flake = false;
    };

    Saturn = {
      url = "github:OceanRamen/Saturn";
      flake = false;
    };

    Showman = {
      url = "github:12problems/Showman";
      flake = false;
    };

    smods = {
      url = "github:Steamodded/smods";
      flake = false;
    };

    solatro = {
      url = "github:bryanthaboi/solatro";
      flake = false;
    };

    SoulEverything = {
      url = "github:OppositeWolf770/SoulEverything";
      flake = false;
    };

    Temperance = {
      url = "github:luccamargiotta/Temperance";
      flake = false;
    };

    Trance = {
      url = "github:SpectralPack/Trance";
      flake = false;
    };

    Troubadour = {
      url = "github:Eternalnacho/Troubadour";
      flake = false;
    };

    UnBlind = {
      url = "github:MeraGenio/UnBlind";
      flake = false;
    };

    Yorick = {
      url = "github:Somethingcom515/Yorick";
      flake = false;
    };

    ZokersModMenu = {
      url = "github:1Zoker/ZokersModMenu";
      flake = false;
    };
  };

  outputs =
    { self, ... }@args:
    let
      declaredMods = removeAttrs args [ "self" ];
      rootContents = builtins.readDir self.outPath;
      names = builtins.attrNames rootContents;
      dirNames = builtins.filter (name: rootContents.${name} == "directory") names;

      localMods = builtins.listToAttrs (
        map (name: {
          name = name;
          value = builtins.path {
            name = "source-${name}";
            path = "${self.outPath}/${name}";
          };
        }) dirNames
      );
    in
    {
      mods = declaredMods // localMods;
    };
}
