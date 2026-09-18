# PIA dedicated IP with manual WireGuard

The work profile installs `pia-setup` and the fish aliases `pia` and `piaoff`.
`pia` uses the API flow from PIA's official manual-connection scripts, registers
fresh WireGuard keys on every connection, and starts the tunnel with `wg-quick`.
Installing or rebuilding never connects the VPN.

## Connect and disconnect

After rebuilding, open a new fish terminal and run:

```console
pia
```

The command:

1. Disconnects any previous PIA connection managed by this helper.
2. Reuses your saved login and dedicated IP token, prompting on first use.
3. Registers fresh WireGuard keys with your dedicated server.
4. Starts an IPv4 tunnel, letting `wg-quick` choose the MTU and manage routes.
5. Checks the handshake, HTTPS through the tunnel, and normal DNS and routing.
   Both public IP checks must match your dedicated IP.
6. Removes the new tunnel if connection verification fails or is cancelled.

Enter your laptop's sudo password if requested. On first use, the helper also
asks for your PIA username, password, and dedicated IP token. Password and token
input is hidden. To replace saved credentials, use `pia --new-credentials`.
Enter secrets only at the prompts, never in command arguments or the repository.

To disconnect:

```console
piaoff
```

These aliases expand to `pia-setup --connect` and `pia-setup --disconnect`.
The manual interface is named `pia-manual` and excluded from NetworkManager
management. Use these commands to control it; Noctalia still controls the
separate saved NetworkManager profile.

## Routing and connection checks

Internet IPv4 traffic uses PIA, retaining normal local-network routes and the
underlying network's DNS settings. The helper adds no PIA DNS servers or IPv6
tunnel routes. IPv6 connectivity on other interfaces remains outside PIA.

The tunnel check uses Cloudflare's numeric HTTPS endpoint
`https://1.1.1.1/cdn-cgi/trace`, independently of DNS. A second check uses
`https://api.ipify.org` through normal DNS and routing. These checks do not change
your DNS servers. An outage of either check service can fail verification.

Disconnect WARP or another full-tunnel VPN before using PIA. The helper does not
coordinate other VPNs or install a persistent firewall kill switch, port
forwarding, or a background daemon. Verification runs when you connect; it does
not continuously monitor the connection. Run `pia` again to refresh it.

## Optional saved NetworkManager profile

Running `pia-setup` without flags, or opening the **PIA Setup** launcher, prepares
the saved **PIA Dedicated** profile for Noctalia. Setup does not activate it.
The profile uses IPv4, retains normal DNS, and disables IPv6 on its interface.

The Noctalia button uses the saved keys; it does not refresh PIA registration or
verify a working tunnel. Prefer `pia` for fresh registration and verified manual
connection. `pia` disconnects this saved profile before starting the manual
tunnel, and `piaoff` handles either PIA connection.

## Credentials and validation

Runtime files have root-only permissions:

- `/var/lib/pia-noctalia/credentials.json`: saved PIA login and dedicated token.
- `/var/lib/pia-noctalia/pia-manual.conf`: current manual WireGuard configuration.
- `/etc/NetworkManager/system-connections/pia-dedicated.nmconnection`: optional
  saved NetworkManager profile.

These files contain secrets and must stay outside Git and the Nix store.
Rebuilding preserves the saved credentials. A fresh installation needs initial
credential input because these files are machine-local. Never copy them into
this repository, even under a Git-ignored path.

Offline tests cover the API flow with synthetic replies, credential handling,
real NetworkManager keyfile parsing, manual configuration, verification errors,
and failure cleanup. They never activate a VPN. A real dedicated IP connection,
DNS behavior, suspend/resume, and reconnect still need live testing.

Sources:

- [PIA manual-connections, pinned revision](https://github.com/pia-foss/manual-connections/tree/a1412dbe2ca41edbb79c766bc475335cb6cb13ad)
- [wg-quick configuration and routing](https://git.zx2c4.com/wireguard-tools/about/src/man/wg-quick.8)
- [ipify public IP API](https://www.ipify.org/)
- [NetworkManager WireGuard routing](https://networkmanager.dev/docs/api/latest/settings-wireguard.html)
