{ pkgs, ... }:

{
  programs.obs-studio = {
    enable = true;

    plugins = with pkgs; [
      obs-vkcapture
      obs-pipewire-audio-capture
      input-overlay
      waveform
    ];
  };
}
