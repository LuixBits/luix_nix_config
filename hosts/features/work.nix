# System services and machine-wide policy required by the work environment.
{ config, primaryUser, ... }:
let
  # Keep the company CA outside the public repository. Reading this local file
  # requires --impure when evaluating or rebuilding the work configuration.
  cloudflareCertificatePath =
    "${config.users.users.${primaryUser}.home}/.local/share/cloudflare-warp/siga-cloudflare-root.pem";
  cloudflareCertificate = builtins.readFile cloudflareCertificatePath;
in
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

  # Nix keeps local build copies of this CA; no certificate material is in Git.
  security.pki.certificates = [ cloudflareCertificate ];
  environment.etc."ssl/certs/siga-cloudflare-root.pem".text = cloudflareCertificate;

  # Fetch builders inherit this from the daemon, not the interactive shell.
  # Nix mounts the host CA bundle at this exact path inside download sandboxes;
  # a store-path bundle can be absent there and fall back to public CAs only.
  nix.settings.ssl-cert-file = "/etc/ssl/certs/ca-certificates.crt";
  systemd.services.nix-daemon.environment.NIX_SSL_CERT_FILE =
    "/etc/ssl/certs/ca-certificates.crt";

  # Apply to the existing Home Manager Firefox package, including its separate
  # admin profile. Firefox imports this CA when the browser starts.
  environment.etc."firefox/policies/policies.json".text = builtins.toJSON {
    policies.Certificates.Install = [ "/etc/ssl/certs/siga-cloudflare-root.pem" ];
  };

  networking.extraHosts = ''
    127.0.0.1 siga-webshop.local siga-blog.local roi.local webauth.local siga-webauth.local
  '';

  # Teams on the web uses Chrome's Idle Detection API to keep presence
  # accurate while another application is focused.
  environment.etc."opt/chrome/policies/managed/teams.json".text = builtins.toJSON {
    IdleDetectionAllowedForUrls = [ "https://teams.microsoft.com" ];
  };
}
