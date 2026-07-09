{
  mkWgInterface =
    {
      privateKeyPath,
      publicKey,
      endpoint,
      address ? [ "10.2.0.2/32" ],
    }:
    {
      wg0 = {
        inherit address;
        privateKeyFile = privateKeyPath;
        dns = [
          "1.1.1.1"
          "8.8.8.8"
          "9.9.9.9"
          "116.202.176.26"
          "10.2.0.1"
        ];
        peers = [
          {
            inherit publicKey endpoint;
            allowedIPs = [
              "0.0.0.0/0"
              "::/0"
            ];
          }
        ];
      };
    };
}
