{
  userName,
  ...
}:

{
  age.secrets = {
    "${userName}-passwd".file = ../secrets/${userName}-passwd-hash.age;
    gh-pat.file = ../secrets/gh-pat.age;
    dc-tkn = {
      file = ../secrets/dc-tkn.age;
      owner = userName;
    };
  };
}
