"""Prepare a PIA profile, or explicitly connect with fresh manual WireGuard setup.

API flow: pia-foss/manual-connections at a1412dbe2ca41edbb79c766bc475335cb6cb13ad,
get_token.sh, get_dip.sh, and connect_to_wireguard_with_token.sh.
"""

import argparse
import base64
import binascii
import fcntl
import getpass
import ipaddress
import json
import os
from pathlib import Path
import re
import signal
import stat
import subprocess
import sys
import tempfile
import uuid

CURL = "@curl@"
NMCLI = "@nmcli@"
WG = "@wg@"
WG_QUICK = "@wg-quick@"
CERTIFICATE = "@certificate@"
STATE = Path("/var/lib/pia-noctalia")
PROFILE = Path("/etc/NetworkManager/system-connections/pia-dedicated.nmconnection")
PROFILE_UUID = str(uuid.uuid5(uuid.NAMESPACE_URL, "luix-nix-config:pia-dedicated"))
MANUAL_INTERFACE = "pia-manual"
MANUAL_CONFIG = STATE / f"{MANUAL_INTERFACE}.conf"
API = "https://www.privateinternetaccess.com/api/client/v2"


class SetupError(Exception):
    pass


def run(command, data=None, label="Command"):
    result = subprocess.run(
        command, input=data, text=True, capture_output=True, timeout=60, check=False
    )
    if result.returncode:
        # Commands and HTTP bodies may contain secrets. Never echo them on error.
        raise SetupError(f"{label} failed (exit {result.returncode}).")
    return result.stdout


def curl_quote(value):
    return (
        '"'
        + str(value)
        .replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
        + '"'
    )


def request_json(label, options):
    config = "\n".join(f"{key} = {curl_quote(value)}" for key, value in options)
    # Secrets go through stdin, not argv, environment, shell history, or logs.
    response = run(
        [
            CURL,
            "-q",
            "--silent",
            "--fail",
            "--connect-timeout",
            "15",
            "--max-time",
            "45",
            "--proto",
            "=https",
            "--config",
            "-",
        ],
        config,
        label,
    )
    try:
        return json.loads(response)
    except json.JSONDecodeError:
        raise SetupError(f"{label} returned an invalid response.") from None


def validate_credentials(credentials):
    if not isinstance(credentials, dict):
        raise SetupError("The saved credentials are invalid; use --new-credentials.")
    for key in ("username", "password", "dip_token"):
        value = credentials.get(key)
        if not isinstance(value, str) or not value or any(ord(c) < 32 for c in value):
            raise SetupError(f"Missing or invalid {key}; use --new-credentials.")
    if ":" in credentials["dip_token"]:
        raise SetupError("The dedicated IP token must not contain a colon.")
    return credentials


def credentials_for_setup(path, replace):
    if path.exists() and not replace:
        info = path.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_uid != 0 or info.st_mode & 0o077:
            raise SetupError(
                "The saved credentials must be a root-owned, private file."
            )
        print("Reusing saved PIA credentials.")
        return validate_credentials(json.loads(path.read_text()))
    if not sys.stdin.isatty():
        raise SetupError("Run setup in your terminal to enter credentials privately.")
    print(
        "Enter your PIA login and dedicated IP token. Password and token stay hidden."
    )
    return validate_credentials(
        {
            "username": input("PIA username: ").strip(),
            "password": getpass.getpass("PIA password: "),
            "dip_token": getpass.getpass("PIA dedicated IP token: ").strip(),
        }
    )


def dedicated_endpoint(credentials):
    auth = request_json(
        "PIA login",
        [
            ("url", f"{API}/token"),
            ("form-string", f"username={credentials['username']}"),
            ("form-string", f"password={credentials['password']}"),
        ],
    )
    token = auth.get("token") if isinstance(auth, dict) else None
    if not isinstance(token, str) or not token or any(ord(c) < 32 for c in token):
        raise SetupError("PIA rejected the login. Check your username and password.")
    endpoints = request_json(
        "Dedicated IP lookup",
        [
            ("url", f"{API}/dedicated_ip"),
            ("header", "Content-Type: application/json"),
            ("header", f"Authorization: Token {token}"),
            ("data", json.dumps({"tokens": [credentials["dip_token"]]})),
        ],
    )
    if (
        not isinstance(endpoints, list)
        or not endpoints
        or not isinstance(endpoints[0], dict)
        or endpoints[0].get("status") != "active"
    ):
        raise SetupError("PIA did not accept this dedicated IP token as active.")
    address = str(ipaddress.IPv4Address(endpoints[0]["ip"]))
    hostname = endpoints[0]["cn"]
    if not isinstance(hostname, str) or not re.fullmatch(
        r"[A-Za-z0-9][A-Za-z0-9.-]{0,252}", hostname
    ):
        raise SetupError("PIA returned an invalid server hostname.")
    return address, hostname


def register_key(credentials, address, hostname, public_key):
    response = request_json(
        "WireGuard key registration",
        [
            ("url", f"https://{hostname}:1337/addKey"),
            ("connect-to", f"{hostname}:1337:{address}:1337"),
            ("cacert", CERTIFICATE),
            ("user", f"dedicated_ip_{credentials['dip_token']}:{address}"),
            ("get", ""),
            ("data-urlencode", f"pubkey={public_key}"),
        ],
    )
    if not isinstance(response, dict) or response.get("status") != "OK":
        raise SetupError("The dedicated server rejected WireGuard registration.")
    return response


def validate_key(value):
    if not isinstance(value, str) or len(base64.b64decode(value, validate=True)) != 32:
        raise SetupError("Invalid WireGuard key in the setup response.")
    return value


def connection_values(address, private_key, response):
    address = str(ipaddress.IPv4Address(address))
    private_key = validate_key(private_key)
    server_key = validate_key(response["server_key"])
    peer_ip = str(ipaddress.IPv4Address(response["peer_ip"]))
    port = int(response["server_port"])
    if not 1 <= port <= 65535:
        raise SetupError("PIA returned an invalid WireGuard port.")
    return address, private_key, server_key, peer_ip, port


def make_profile(address, private_key, response):
    address, private_key, server_key, peer_ip, port = connection_values(
        address, private_key, response
    )
    # Use PIA for IPv4 while keeping the underlying network's DNS settings.
    # PIA's manual WireGuard service is IPv4-only, so disable IPv6 on this
    # interface and leave other interfaces' IPv6 configuration alone.
    return f"""[connection]
id=PIA Dedicated
uuid={PROFILE_UUID}
type=wireguard
interface-name=pia-dedicated
autoconnect=false

[wireguard]
private-key={private_key}
private-key-flags=0
mtu=1420
peer-routes=true
ip4-auto-default-route=1
ip6-auto-default-route=0

[wireguard-peer.{server_key}]
endpoint={address}:{port}
allowed-ips=0.0.0.0/0;
persistent-keepalive=25

[ipv4]
method=manual
address1={peer_ip}/32

[ipv6]
method=disabled
"""


def make_manual_config(address, private_key, response):
    address, private_key, server_key, peer_ip, port = connection_values(
        address, private_key, response
    )
    # Match PIA's manual WireGuard configuration without optional DNS or IPv6.
    # wg-quick chooses the MTU from the underlying network and manages routes.
    return f"""[Interface]
Address = {peer_ip}/32
PrivateKey = {private_key}

[Peer]
PublicKey = {server_key}
Endpoint = {address}:{port}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
"""


def atomic_write(path, content):
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as handle:
            os.fchmod(handle.fileno(), 0o600)
            handle.write(content)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def install_profile(profile):
    # Parse and normalize with NetworkManager before changing the saved file.
    normalized = run(
        [NMCLI, "--offline", "connection", "modify", "connection.autoconnect", "no"],
        profile,
        "NetworkManager profile validation",
    )
    PROFILE.parent.mkdir(parents=True, exist_ok=True)
    previous = PROFILE.read_text() if PROFILE.exists() else None
    atomic_write(PROFILE, normalized)
    try:
        run(
            [NMCLI, "connection", "load", str(PROFILE)],
            label="Saving the VPN connection",
        )
    except SetupError:
        if previous is None:
            PROFILE.unlink()
        else:
            atomic_write(PROFILE, previous)
        raise


def networkmanager_active():
    return (
        PROFILE_UUID
        in run(
            [NMCLI, "--terse", "--fields", "UUID", "connection", "show", "--active"],
            label="Checking NetworkManager",
        ).splitlines()
    )


def manual_active():
    return (
        MANUAL_INTERFACE
        in run([WG, "show", "interfaces"], label="Checking WireGuard").split()
    )


def disconnect_manual():
    if manual_active():
        if not MANUAL_CONFIG.is_file():
            raise SetupError("The manual PIA interface has no saved configuration.")
        run([WG_QUICK, "down", str(MANUAL_CONFIG)], label="Disconnecting manual PIA")


def disconnect():
    # Both profiles belong to this helper. Leave every other VPN alone.
    if networkmanager_active():
        run(
            [NMCLI, "--wait", "15", "connection", "down", "uuid", PROFILE_UUID],
            label="Disconnecting the saved PIA connection",
        )
    disconnect_manual()


def prepare_connection(replace_credentials):
    credentials = credentials_for_setup(STATE / "credentials.json", replace_credentials)
    print("Checking PIA login and dedicated IP…", flush=True)
    address, hostname = dedicated_endpoint(credentials)
    private_key = run([WG, "genkey"], label="Generating a WireGuard key").strip()
    public_key = run(
        [WG, "pubkey"], private_key + "\n", "Reading the public key"
    ).strip()
    response = register_key(credentials, address, hostname, public_key)
    return credentials, address, private_key, response


def has_handshake(server_key):
    for line in run(
        [WG, "show", MANUAL_INTERFACE, "latest-handshakes"],
        label="Checking the WireGuard handshake",
    ).splitlines():
        fields = line.split()
        if len(fields) == 2 and fields[0] == server_key and int(fields[1]) > 0:
            return True
    return False


def connection_probe(url, interface=None):
    command = [
        CURL,
        "-q",
        "--ipv4",
        "--silent",
        "--fail",
        "--noproxy",
        "*",
        "--connect-timeout",
        "4",
        "--max-time",
        "8",
        "--proto",
        "=https",
    ]
    if interface:
        command += ["--interface", interface]
    return run([*command, url], label="IPv4 connection check").strip()


def verify_connection(address, server_key):
    # This probe also triggers the WireGuard handshake. Its numeric destination
    # tests the tunnel independently of DNS, with normal TLS verification.
    tunnel_ip = None
    handshake = False
    for _ in range(3):
        try:
            trace = connection_probe(
                "https://1.1.1.1/cdn-cgi/trace", interface=MANUAL_INTERFACE
            )
            for line in trace.splitlines():
                if line.startswith("ip="):
                    tunnel_ip = str(ipaddress.IPv4Address(line[3:]))
        except (SetupError, ValueError):
            pass
        handshake = has_handshake(server_key)
        if tunnel_ip is not None and handshake:
            break
    if not handshake:
        raise SetupError(
            "No WireGuard handshake after refreshing PIA. Check Wi-Fi, the PIA server, "
            "or UDP restrictions on this network."
        )
    if tunnel_ip is None:
        raise SetupError("WireGuard handshook, but the IPv4 HTTPS tunnel check failed.")
    if tunnel_ip != address:
        raise SetupError(
            "The tunnel's public IPv4 does not match your PIA dedicated IP."
        )

    # Use normal DNS and routing here, ensuring ordinary applications will also
    # use the dedicated IP. A proxy must not disguise a broken default route.
    try:
        public_ip = str(
            ipaddress.IPv4Address(connection_probe("https://api.ipify.org"))
        )
    except (SetupError, ValueError):
        raise SetupError(
            "The WireGuard tunnel works, but the normal DNS/HTTPS check failed."
        ) from None
    if public_ip != address:
        raise SetupError("Normal IPv4 traffic is not using your PIA dedicated IP.")


def connect(replace_credentials):
    print("Disconnecting any previous PIA connection before refreshing…", flush=True)
    disconnect()
    credentials, address, private_key, response = prepare_connection(
        replace_credentials
    )
    atomic_write(MANUAL_CONFIG, make_manual_config(address, private_key, response))
    atomic_write(STATE / "credentials.json", json.dumps(credentials) + "\n")
    print("Connecting with wg-quick and verifying the dedicated IP…", flush=True)
    try:
        run([WG_QUICK, "up", str(MANUAL_CONFIG)], label="Connecting manual PIA")
        verify_connection(address, response["server_key"])
    except BaseException:
        # Also undo a partially successful startup or an interrupted check.
        try:
            disconnect_manual()
            print("PIA disconnected; its tunnel routes have been removed.", flush=True)
        except (SetupError, OSError, subprocess.TimeoutExpired):
            print("PIA cleanup failed. Run piaoff to disconnect it.", file=sys.stderr)
        raise
    print(f"PIA connected and verified. Public IPv4: {address}")
    print("DNS uses your normal network. Run piaoff to disconnect.")


def setup(replace_credentials):
    if networkmanager_active() or manual_active():
        raise SetupError(
            "Disconnect PIA before refreshing its saved profile, or use pia to reconnect."
        )
    credentials, address, private_key, response = prepare_connection(
        replace_credentials
    )
    install_profile(make_profile(address, private_key, response))
    atomic_write(STATE / "credentials.json", json.dumps(credentials) + "\n")
    print(f"Saved PIA Dedicated. Expected public IPv4 address: {address}")
    print("Open Noctalia → Network → VPNs → PIA Dedicated and click the plug button.")
    print("For this first test, disconnect Cloudflare WARP before connecting PIA.")
    print(
        "Internet IPv4 uses PIA. DNS stays with your current network; IPv6 is disabled on the VPN interface."
    )
    print(
        "Setup has not connected the VPN. The profile and credentials are saved for reuse."
    )


def main():
    parser = argparse.ArgumentParser(
        prog="pia-setup", description=__doc__.splitlines()[0]
    )
    parser.add_argument(
        "--new-credentials",
        action="store_true",
        help="replace saved PIA login and token",
    )
    action = parser.add_mutually_exclusive_group()
    action.add_argument(
        "--connect",
        action="store_true",
        help="refresh registration and connect with wg-quick",
    )
    action.add_argument(
        "--disconnect",
        action="store_true",
        help="disconnect this helper's PIA connections",
    )
    args = parser.parse_args()
    if args.disconnect and args.new_credentials:
        parser.error("--new-credentials cannot be used with --disconnect")
    if os.geteuid() != 0:
        print(
            "Managing PIA WireGuard requires your laptop's sudo password.",
            flush=True,
        )
        os.execv(
            "/run/wrappers/bin/sudo",
            [
                "sudo",
                sys.executable,
                "-I",
                str(Path(__file__).resolve()),
                *sys.argv[1:],
            ],
        )
    os.umask(0o077)
    STATE.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = STATE.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != 0 or info.st_mode & 0o077:
        raise SetupError("The PIA state directory must be private and owned by root.")
    with (STATE / "setup.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise SetupError("Another PIA setup is already running.") from None
        if args.connect:

            def interrupted(signum, frame):
                raise KeyboardInterrupt

            signal.signal(signal.SIGTERM, interrupted)
            signal.signal(signal.SIGHUP, interrupted)
            connect(args.new_credentials)
        elif args.disconnect:
            disconnect()
            print("PIA disconnected.")
        else:
            setup(args.new_credentials)


if __name__ == "__main__":
    try:
        main()
    except SetupError as error:
        sys.exit(str(error))
    except (KeyError, TypeError, ValueError, binascii.Error):
        sys.exit("PIA returned unexpected data, or the saved credentials are invalid.")
    except (OSError, subprocess.TimeoutExpired):
        sys.exit("PIA could not finish a network, command, or file operation.")
    except (KeyboardInterrupt, EOFError):
        sys.exit("PIA command cancelled.")
