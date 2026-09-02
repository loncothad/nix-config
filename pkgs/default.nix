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
    celld-adapter = inputs.celld-adapter.packages.${system};
    fastpotify-adapter = inputs.fastpotify-adapter.packages.${system};
    mark-shot = inputs.mark-shot.packages.${system};
    openai-codex-adapter = inputs.openai-codex-adapter.packages.${system};
    wine4office-adapter = inputs.wine4office-adapter.packages.${system};
    zcode-adapter = inputs.zcode-adapter.packages.${system};
    zvec-grep-adapter = inputs.zvec-grep-adapter.packages.${system};
  };
}
