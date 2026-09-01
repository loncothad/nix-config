{ inputs }:

final: _prev:
let
  system = final.stdenv.hostPlatform.system;
in
{
  fromFlakes = {
    agenix = inputs.agenix.packages.${system};
    agenix-rekey = inputs.agenix-rekey.packages.${system};
    autolith = inputs.autolith.packages.${system};
    celld = inputs.celld.packages.${system};
    fastpotify-adapter = inputs.fastpotify-adapter.packages.${system};
    mark-shot = inputs.mark-shot.packages.${system};
    wine4office = inputs.wine4office.packages.${system};
  };
}
