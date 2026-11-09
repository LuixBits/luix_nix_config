{ pkgs, ... }:
let
  xterm = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@xterm/xterm/-/xterm-5.5.0.tgz";
    hash = "sha512-hqJHYaQb5OptNunnyAnkHyM8aCjZ1MEIDTQu1iIbbTD/xops91NB5yq1ZK/dC2JDbVWtF23zUtl9JE2NqwT87A==";
  };
  fit = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@xterm/addon-fit/-/addon-fit-0.10.0.tgz";
    hash = "sha512-UFYkDm4HUahf2lnEyHvio51TNGiLK66mqP2JoATy7hRZeXaGMRDr00JiSF7m63vR5WKATF605yEggJKsw0JpMQ==";
  };
  settings = pkgs.writeText "luix-panel-settings.json" (builtins.toJSON {
    btopCommand = "${pkgs.btop}/bin/btop";
  });
  btopPlugin = pkgs.runCommand "cockpit-luix-server" { } ''
    target="$out/share/cockpit/luix-server"
    mkdir -p "$target/vendor" xterm fit
    cp ${./control-panel}/{manifest.json,index.html,overview.js,style.css,btop.html,btop.js} "$target/"
    cp ${settings} "$target/settings.json"
    tar -xzf ${xterm} -C xterm --strip-components=1
    tar -xzf ${fit} -C fit --strip-components=1
    cp xterm/lib/xterm.js xterm/css/xterm.css "$target/vendor/"
    cp fit/lib/addon-fit.js "$target/vendor/"
    cp xterm/LICENSE "$target/vendor/xterm-LICENSE"
    cp fit/LICENSE "$target/vendor/addon-fit-LICENSE"
  '';
in
{
  services.cockpit = {
    enable = true;
    openFirewall = false;
    showBanner = false;
    plugins = [ btopPlugin ];
    allowed-origins = [
      "https://192.168.18.26:9090"
      "https://nixos-server:9090"
    ];
    settings = {
      WebService = {
        LoginTitle = "Luix server";
        LoginTo = false;
        AllowUnencrypted = false;
      };
      Session.IdleTimeout = 30;
    };
  };

  # Access through the LAN interface; no public hosting or router changes.
  networking.firewall.interfaces.eno1.allowedTCPPorts = [ 9090 ];
  services.udisks2.enable = true;
  services.udisks2.settings."udisks2.conf".udisks2.modules = [ "btrfs" "lvm2" ];
  # Probe an already assembled array without enabling automatic RAID assembly.
  services.udev.extraRules = ''
    SUBSYSTEM=="block", KERNEL=="md[0-9]*", IMPORT{builtin}="blkid"
  '';
  security.polkit.enable = true;
  environment.etc."cockpit/disallowed-users".text = "root\n";
}
