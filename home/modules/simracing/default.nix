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
  quest = pkgs.callPackage ./quest.nix {
    wivrn = osConfig.services.wivrn.package or pkgs.wivrn;
    defaultSerial = cfg.quest.serial;
  };
  boxflat = pkgs.writeShellApplication {
    name = "boxflat";
    runtimeInputs = [ pkgs.flatpak ];
    text = ''
      exec flatpak run --system io.github.lawstorant.boxflat "$@"
    '';
  };
in
{
  options.luix.simracing = {
    enable = lib.mkEnableOption "the Boxflat and wired Quest simracing environment";
    vr.enable = lib.mkEnableOption "the wired Quest launcher" // {
      default = osConfig.luix.simracing.vr.enable or true;
    };
    quest.serial = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "USB serial of the Quest to use; null selects the only connected, authorized Quest.";
    };
    quest.package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      internal = true;
      default = quest;
      description = "The wired Quest launcher and its offline checks.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = osConfig.luix.simracing.enable or false;
        message = "Home Manager simracing requires the simracing/nixos.nix companion with luix.simracing.enable = true for device permissions and system packages.";
      }
      {
        assertion = !cfg.vr.enable || (osConfig.services.wivrn.enable or false);
        message = "The simracing Quest launcher requires services.wivrn.enable in NixOS.";
      }
    ];

    home.packages = [
      boxflat
    ]
    ++ lib.optionals cfg.vr.enable [
      pkgs.android-tools
      quest
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
