# /etc/nixos/modules/caddy.nix
{ lib, pkgs, ... }:

{
  services.caddy = {
    enable = true;
    virtualHosts = {
      "siga-webshop.local".extraConfig = ''
        tls internal
        reverse_proxy http://127.0.0.1:8098
      '';
      "siga-blog.local".extraConfig = ''
        tls internal
        reverse_proxy http://127.0.0.1:8098
      '';
      "roi.local".extraConfig = ''
        tls internal
        reverse_proxy http://127.0.0.1:8084
      '';
      "webauth.local".extraConfig = ''
        tls internal
        reverse_proxy http://127.0.0.1:8088
      '';

    };
  };
  # Map the .local names to localhost
  networking.extraHosts = ''
    127.0.0.1 siga-webshop.local siga-blog.local roi.local webauth.local
  '';
}

