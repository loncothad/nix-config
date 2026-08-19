{ pkgs, ... }:

{
  programs.pi = {
    enable = true;

    packages = with pkgs.piExtensions; [
      pi-effort
      pi-subagents
      pi-goal-x
      pi-web-access
      pi-grok-cli
    ];

    settings = {
      theme = "dark";
      defaultProvider = "openrouter";
      defaultModel = "qwen/qwen3.8-27b";
      defaultThinkingLevel = "medium";
    };
  };
}
