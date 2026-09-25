# System services and machine-wide policy required by the work environment.
{ ... }:
{
  imports = [
    ./appimage.nix
    ./pia
  ];

  # Docker itself is enabled for every host in hosts/common/base.nix;
  # the work environment only adds boot-time startup and journald logs.
  virtualisation.docker = {
    enableOnBoot = true;
    daemon.settings.log-driver = "journald";
  };

  services = {
    cloudflare-warp.enable = true;
    resolved.enable = true;
    gnome.gnome-keyring.enable = true;
    gnome.gnome-online-accounts.enable = true;
  };
  networking.networkmanager.dns = "systemd-resolved";

  networking.extraHosts = ''
    127.0.0.1 siga-webshop.local siga-blog.local roi.local webauth.local siga-webauth.local
  '';

  # Teams on the web uses Chrome's Idle Detection API to keep presence
  # accurate while another application is focused.
  environment.etc."opt/chrome/policies/managed/teams.json".text = builtins.toJSON {
    IdleDetectionAllowedForUrls = [ "https://teams.microsoft.com" ];
  };
}
