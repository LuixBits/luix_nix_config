# PIA dedicated IP in Noctalia

Noctalia's Network panel controls saved NetworkManager VPN/WireGuard profiles.
It does not have a PIA login or dedicated-token form. This package prepares that
profile once, using the API flow from PIA's official manual-connection scripts.

The work profile imports `hosts/features/pia.nix`, which installs the normal
`pia-setup` command and a **PIA Setup** launcher entry during a NixOS rebuild.
This installs the tool; it never connects the VPN or reruns credential setup.

For initial setup or an occasional connection refresh, press **Super+Space**,
search **PIA Setup**, and open it. A terminal opens for private input and stays
open until you press Enter. You can also run the normal command:

```console
pia-setup
```

Enter your laptop's sudo password if requested, then your PIA username, PIA
password, and dedicated IP token. Password and token input is hidden. Enter
credentials only at these prompts, not as command arguments or in the repository.

After successful setup:

1. Disconnect Cloudflare WARP for the first test if it is connected.
2. Left-click the network icon beside the temperature widget. Alternatively,
   press **Super+S**, then select **Network**, or run:
   `noctalia msg panel-open control-center network`.
3. Find **VPNs**, expand it if needed, and click the plug beside **PIA Dedicated**.
4. Confirm your public IPv4 matches the address printed by setup. A connection
   shown as active is not sufficient to prove the WireGuard handshake succeeded.
5. Click the disconnect/plug-off button to return to your normal connection.

The saved profile survives reboot. Normally you reconnect from the same Noctalia
panel without entering credentials. If PIA discards the server-side registration,
disconnect the profile and rerun the setup command; it reuses the saved login and
token and refreshes the profile. There is no automatic registration-refresh daemon.
To replace your saved credentials, run `pia-setup --new-credentials`.

The helper saves credentials in `/var/lib/pia-noctalia/credentials.json` and the
generated profile in
`/etc/NetworkManager/system-connections/pia-dedicated.nmconnection`, with root-only
file permissions. These contain runtime secrets and must stay outside Git and the
Nix store. The Nix package, helper, and pinned public CA are versioned in this repo.

The source is suitable for a public repository: it contains the API endpoints,
public CA reference, and synthetic test data, not your login, token, or generated
private key. Rebuilding keeps both the installed tool and existing local VPN
state. A fresh installation still needs initial setup because credentials are
machine-local. Ignore rules protect against accidentally committing copies, but
keep secret files outside the repository entirely: a local `path:` flake can copy
even Git-ignored files into the Nix store. Never copy the generated VPN profile
or credential file here.

This is a full Internet IPv4 tunnel, retaining normal local-network routes. DNS
uses PIA's supplied servers through NetworkManager/systemd-resolved. Public IPv6
is routed into the tunnel and is unavailable while connected because PIA's manual
WireGuard service does not forward it. Disconnecting removes the profile's routes
and DNS settings. This does not install a persistent firewall kill switch, perform
port forwarding, or coordinate simultaneous WARP/PIA routing. Autoconnect is off.

The offline tests exercise the API flow with synthetic replies, credential
handling, rollback, and real NetworkManager keyfile parsing. A real dedicated IP,
DNS/IPv6 behavior, suspend/resume, and reconnect still need live testing.

Sources:

- [PIA manual-connections, pinned revision](https://github.com/pia-foss/manual-connections/tree/a1412dbe2ca41edbb79c766bc475335cb6cb13ad)
- [NetworkManager WireGuard routing](https://networkmanager.dev/docs/api/latest/settings-wireguard.html)
- [Noctalia Control Center](https://docs.noctalia.dev/noctalia/control-center/)
