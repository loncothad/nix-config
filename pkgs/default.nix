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
    cargo-multivers-adapter = inputs.cargo-multivers-adapter.packages.${system};
    cargo-pretty-adapter = inputs.cargo-pretty-adapter.packages.${system};
    fastpotify-adapter = inputs.fastpotify-adapter.packages.${system};
    smolvm-adapter = inputs.smolvm-adapter.packages.${system};
    mark-shot = inputs.mark-shot.packages.${system};
    openai-codex-adapter = inputs.openai-codex-adapter.packages.${system};
    wine4office-adapter = inputs.wine4office-adapter.packages.${system};
    zvec-grep-adapter = inputs.zvec-grep-adapter.packages.${system};
  };
}
