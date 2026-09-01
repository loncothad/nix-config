{ pkgs, ... }:

{
  home.packages = [ pkgs.fromFlakes.autolith ];

  home.sessionVariables = {
    AUTOLITH_MODEL = "openrouter/qwen/qwen3.8-27b";
    AUTOLITH_REASONING_EFFORT = "medium";
  };
}
