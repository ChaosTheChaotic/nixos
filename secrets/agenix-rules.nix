let
  keys = {
    m1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDfMMiazOSuhyr0BeX/yOJUfvBr2/UV8syN35EwOQYUd"; # Root
    m2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ30qhQ6jnCuau+6XAfBCLB1LYlLymcjhTnOKiQ93A2E"; # chaos

    t1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC8lTCcXQbedc5Z0Y3M4EwGROzdz5ZoeIxCZ/DKwZ2ER"; # Root
    t2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHNgjfHjKOWgMwjWf3/viQjRKadDpqzuYBkzr8TTSRai"; # chaos
    ttpm = "age1tag1qtlfg5h35ukqvare3v9j0sqwzuek6wvdw6a7pl4due9hl2f4rwa2kvurwy5"; # tpm chip
  };

  getWPfx =
    pfx:
    let
      pfxLen = builtins.stringLength pfx;
      allNames = builtins.attrNames keys;
      matchedNames = builtins.filter (name: builtins.substring 0 pfxLen name == pfx) allNames;
    in
    map (name: keys.${name}) matchedNames;

  all = builtins.attrValues keys;
  mKeys = getWPfx "m";
  tKeys = getWPfx "t";
in
{
  "chaos-passwd-hash.age" = {
    publicKeys = [
      all
    ];
    armour = true;
  };
  "wg-priv-asahi.age" = {
    publicKeys = [
      mKeys
    ];
    armour = true;
  };
  "wg-priv-thinker.age" = {
    publicKeys = [
      tKeys
    ];
    armour = true;
  };
  "gh-pat.age" = {
    publicKeys = [
      all
    ];
    armour = true;
  };

  "syncthing-key-asahi.age" = {
    publicKeys = [
      mKeys
    ];
    armour = true;
  };
  "syncthing-key-thinker.age" = {
    publicKeys = [
      tKeys
    ];
    armour = true;
  };
}
