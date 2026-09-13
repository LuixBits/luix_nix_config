{
  config,
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  cfg = config.luix.simracing;
  initialSettings = pkgs.writeText "boxflat-settings.yml" "rules-version: 2\n";
in
{
  options.luix.simracing.enable = lib.mkEnableOption "the Boxflat user settings and simracing guide";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = osConfig.luix.simracing.enable or false;
        message = "Home Manager simracing requires the simracing/nixos.nix companion with luix.simracing.enable = true for device permissions and system packages.";
      }
    ];

    # Boxflat's installer cannot write NixOS's store-backed udev rules.
    # Merge its version flag only; calibration and presets remain app-managed.
    home.activation.boxflatUdevRulesVersion = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      settings_dir=${lib.escapeShellArg "${config.home.homeDirectory}/.var/app/io.github.lawstorant.boxflat/.config/boxflat"}
      settings_file="$settings_dir/settings.yml"
      if [ -f "$settings_file" ]; then
        rules_version=$(${pkgs.yq-go}/bin/yq '."rules-version" // 0' "$settings_file")
        if ! [[ "$rules_version" =~ ^[0-9]+$ && "$rules_version" -ge 2 ]]; then
          run ${pkgs.yq-go}/bin/yq -i '."rules-version" = 2' "$settings_file"
        fi
      else
        run mkdir -p "$settings_dir"
        run install -m 0600 ${initialSettings} "$settings_file"
      fi
    '';

    xdg.dataFile."simracing/README.md".source = ./README.md;
  };
}
