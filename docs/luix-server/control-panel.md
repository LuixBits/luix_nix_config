# Server start page and control panel

[Start page](http://192.168.18.26/): custom static HTML/CSS/JS served by Nginx on this server. Search with `/`; links open in new tabs. Categories stay as they are for now.

[System details](https://192.168.18.26:9090/system): native Cockpit Overview. Cockpit is an existing open-source application; the launcher and btop integration are custom.

Built and staged in `/etc/nixos`: remove the duplicate **Luix server** stats tab and its polling helper. Keep btop; old bookmarks redirect to Overview. Activation is pending under the repository's rebuild policy.

- Login: `luix-server`, current server password. The local certificate produces a browser trust prompt.
- **Overview / Usage graphs:** system health and live usage; historical collection is not configured.
- **Processes · btop:** interactive monitor; click inside or use **Focus monitor**. Pauses when hidden.
- **Services / Logs:** inspect units/logs. Authenticate under **Limited access** for controls.
- **Storage:** drive details and SMART. Temporary inspection mounts can appear “not mounted”; check `findmnt` in Terminal.
- **Terminal:** shell as the logged-in user; use `sensors` for temperatures and fans.

Flyff opens [flyff.luizperren.dev](https://flyff.luizperren.dev). Other app tiles remain unlinked. Edit [links.json](../../hosts/nixos-server/launcher/links.json) when ready.

Both interfaces are LAN-accessible. Administrative pages require HTTPS and login. Configuration stays in Nix.

Checked: Nix build; browser preview with local assets for Overview, redirect, btop keyboard/restart and mobile layout. Running server unchanged. Source backup: `/var/backups/luix-server-overview.0kNqiz/`.
