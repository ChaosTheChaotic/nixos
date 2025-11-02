let
  u1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDfMMiazOSuhyr0BeX/yOJUfvBr2/UV8syN35EwOQYUd"; # Root
  u2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ30qhQ6jnCuau+6XAfBCLB1LYlLymcjhTnOKiQ93A2E"; # chaos
in
  {
  "wg-priv.age" = {
    publicKeys = [ u1 u2 ];
    armour = true;
  };
}
