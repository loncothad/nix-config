{ inputs, ... }:

{
  services.ssh-agent.enable = true;

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    # Git (and ssh) only auto-load id_ecdsa_sk / id_ed25519_sk.
    # FEITIAN handles live as ~/.ssh/id_072 and id_365 after `just sk-load`.
    settings."*" = {
      AddKeysToAgent = "yes";
      IdentitiesOnly = true;
      IdentityFile = [
        "~/.ssh/id_072"
        "~/.ssh/id_365"
      ];
    };
  };

  home.file = {
    ".ssh/id_072.pub".source = inputs.self + "/misc/ssh-keys/id_072.pub";
    ".ssh/id_365.pub".source = inputs.self + "/misc/ssh-keys/id_365.pub";
  };
}
