{ pkgs, ... }:
{
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    daemon.settings = {
      log-driver = "journald";
      features.buildkit = true;
    };
  };

  programs.java = {
    enable = true;
    package = pkgs.jdk;
  };

  services.cloudflare-warp.enable = true;
  services.resolved.enable = true;
  networking.networkmanager.dns = "systemd-resolved";

  environment.systemPackages = with pkgs; [
    cloudflare-warp
    mysql84
    nodejs_24

    (php83.buildEnv {
      extraConfig = ''
        memory_limit = 2G
        upload_max_filesize = 500M
        post_max_size = 500M
      '';
    })

    wireguard-tools
  ];

  services.gnome.gnome-keyring.enable = true;
  services.gnome.gnome-online-accounts.enable = true;
}
