let
  m1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDfMMiazOSuhyr0BeX/yOJUfvBr2/UV8syN35EwOQYUd"; # Root
  m2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ30qhQ6jnCuau+6XAfBCLB1LYlLymcjhTnOKiQ93A2E"; # chaos

	t1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC8lTCcXQbedc5Z0Y3M4EwGROzdz5ZoeIxCZ/DKwZ2ER"; # Root
	t2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHNgjfHjKOWgMwjWf3/viQjRKadDpqzuYBkzr8TTSRai"; # chaos
in
{
  "wg-priv-asahi.age" = {
    publicKeys = [
      m1
      m2
    ];
    armour = true;
  };
	"wg-priv-thinker.age" = {
		publicKeys = [
			t1
			t2
		];
		armour = true;
	};
	"gh-pat.age" = {
		publicKeys = [
			m1
			m2
			t1
			t2
		];
		armour = true;
	};
}
