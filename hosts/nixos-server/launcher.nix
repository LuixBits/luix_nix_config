{ pkgs, ... }:
let
  page = pkgs.runCommand "luix-server-launcher" { } ''
    mkdir -p "$out"
    cp ${./launcher}/{index.html,launcher.css,launcher.js,links.json} "$out/"
  '';
in
{
  services.nginx = {
    enable = true;
    virtualHosts."nixos-server" = {
      default = true;
      root = page;
      listen = [ { addr = "0.0.0.0"; port = 80; } ];
      locations."/" = {
        tryFiles = "$uri $uri/ =404";
        extraConfig = ''
          add_header Cache-Control "no-cache" always;
          add_header X-Content-Type-Options "nosniff" always;
          add_header Referrer-Policy "same-origin" always;
          add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; object-src 'none'; base-uri 'self'; frame-ancestors 'none'" always;
        '';
      };
    };
  };
  # Static shortcuts only. Administrative pages keep Cockpit's HTTPS/login.
  networking.firewall.interfaces.eno1.allowedTCPPorts = [ 80 ];
}
