# System services and machine-wide policy required by the work environment.
{ ... }:
{
  imports = [
    ../../hosts/features/appimage.nix
    ../../hosts/features/pia.nix
  ];

  virtualisation.docker = {
    enable = true;
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
    127.0.0.1 siga-webshop.local siga-blog.local roi.local webauth.local
  '';

  # Teams on the web uses Chrome's Idle Detection API to keep presence
  # accurate while another application is focused.
  environment.etc."opt/chrome/policies/managed/teams.json".text = builtins.toJSON {
    IdleDetectionAllowedForUrls = [ "https://teams.microsoft.com" ];
  };
}
