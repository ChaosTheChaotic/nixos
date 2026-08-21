{
	description = "Balatro management flake";

	inputs = {
		balanix.url = "github:ChaosTheChaotic/balanix";

		modding.url = "path:./mods";
	};

	outputs = { balanix, modding, ... }: {
		inherit balanix;
		inherit modding;
	};
}
