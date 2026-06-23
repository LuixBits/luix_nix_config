{ pkgs, ... }:
{
  # Android Emulator needs host KVM access. The work host already gets this via
  # virt-manager, but keep it here as part of the SIGA Android emulator feature.
  users.users.luiz.extraGroups = [ "kvm" ];

  services.dnsmasq = {
    enable = true;
    settings = {
      listen-address = [ "127.0.0.1" ];
      bind-interfaces = true;
      no-hosts = true;
      no-resolv = true;
      server = [
        "1.1.1.1"
        "8.8.8.8"
      ];
      address = [
        "/roi.local/10.0.2.2"
        "/siga-webshop.local/10.0.2.2"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /etc/android-siga 0755 root root - -"
  ];

  systemd.services.android-siga-caddy-ca = {
    description = "Export Caddy local root CA for SIGA Android emulator";
    wantedBy = [ "multi-user.target" ];
    after = [ "caddy.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.coreutils ];
    script = ''
      cert="/var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt"
      target="/etc/android-siga/caddy-local-root.crt"

      if [ -r "$cert" ]; then
        install -Dm0644 "$cert" "$target"
      else
        echo "Caddy local root CA is not available yet at $cert"
      fi
    '';
  };
}
