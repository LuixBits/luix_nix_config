{ config, lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    playerctl
    pavucontrol
    pwvucontrol
  ];

  services.easyeffects = {
    enable = true;

    # EasyEffects 8 handles --load-preset as a one-shot command. Starting it
    # with both --service-mode and --load-preset makes the service exit after
    # loading, so load the preset separately after the daemon is ready.
    preset = "";

    extraPresets = {
      luix-voice = lib.importJSON ./presets/luix-voice.json;
    };
  };

  systemd.user.services.easyeffects.Service = {
    # OBS can remain linked to the virtual source while EasyEffects considers
    # its pipeline idle and disconnects the mic after ten seconds. Keep the
    # pipeline available without requiring microphone listening to wake it.
    # Update only this key before startup; keep the rest of the UI settings
    # writable, including the selected microphone and effects controls.
    ExecStartPre = [
      "${pkgs.coreutils}/bin/mkdir -p ${config.xdg.configHome}/easyeffects/db"
      "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file ${config.xdg.configHome}/easyeffects/db/easyeffectsrc --group EffectsPipelines --key inactivityTimerEnable --type bool false"
    ];
    ExecStartPost = [
      "${pkgs.coreutils}/bin/sleep 0.5"
      "${pkgs.easyeffects}/bin/easyeffects --load-preset luix-voice"
    ];
  };
}
