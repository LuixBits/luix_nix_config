"""Prepare (never activate) a persistent PIA dedicated-IP NetworkManager profile.

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
import stat
import subprocess
import sys
import tempfile
import uuid

CURL = "@curl@"
NMCLI = "@nmcli@"
WG = "@wg@"
CERTIFICATE = "@certificate@"
STATE = Path("/var/lib/pia-noctalia")
PROFILE = Path("/etc/NetworkManager/system-connections/pia-dedicated.nmconnection")
PROFILE_UUID = str(uuid.uuid5(uuid.NAMESPACE_URL, "luix-nix-config:pia-dedicated"))
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


def make_profile(address, private_key, response):
    address = str(ipaddress.IPv4Address(address))
    private_key = validate_key(private_key)
    server_key = validate_key(response["server_key"])
    peer_ip = str(ipaddress.IPv4Address(response["peer_ip"]))
    port = int(response["server_port"])
    if not 1 <= port <= 65535:
        raise SetupError("PIA returned an invalid WireGuard port.")
    dns = [str(ipaddress.IPv4Address(item)) for item in response["dns_servers"]]
    if not dns:
        raise SetupError("PIA returned no DNS servers.")
    # PIA's manual WireGuard service is IPv4-only. Also route IPv6 into the
    # tunnel (where it cannot be forwarded), preventing a public IPv6 bypass.
    # NetworkManager removes these routes when this profile is disconnected.
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
ip6-auto-default-route=1

[wireguard-peer.{server_key}]
endpoint={address}:{port}
allowed-ips=0.0.0.0/0;::/0;
persistent-keepalive=25

[ipv4]
method=manual
address1={peer_ip}/32
dns={";".join(dns)};
dns-search=~.;
dns-priority=-100

[ipv6]
method=manual
address1=fd00:7069:6100::2/128
dns-priority=-100
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


def setup(replace_credentials):
    active = run(
        [NMCLI, "--terse", "--fields", "UUID", "connection", "show", "--active"],
        label="Checking NetworkManager",
    ).splitlines()
    if PROFILE_UUID in active:
        raise SetupError(
            "Disconnect PIA Dedicated in Noctalia before refreshing its setup."
        )
    credentials = credentials_for_setup(STATE / "credentials.json", replace_credentials)
    print("Checking PIA login and dedicated IP…")
    address, hostname = dedicated_endpoint(credentials)
    private_key = run([WG, "genkey"], label="Generating a WireGuard key").strip()
    public_key = run(
        [WG, "pubkey"], private_key + "\n", "Reading the public key"
    ).strip()
    response = register_key(credentials, address, hostname, public_key)
    install_profile(make_profile(address, private_key, response))
    atomic_write(STATE / "credentials.json", json.dumps(credentials) + "\n")
    print(f"Saved PIA Dedicated. Expected public IPv4 address: {address}")
    print("Open Noctalia → Network → VPNs → PIA Dedicated and click the plug button.")
    print("For this first test, disconnect Cloudflare WARP before connecting PIA.")
    print(
        "This profile routes Internet traffic through PIA; public IPv6 is unavailable while connected."
    )
    print(
        "Setup has not connected the VPN. The profile and credentials are saved for reuse."
    )


def main():
    parser = argparse.ArgumentParser(prog="pia-setup", description=__doc__.splitlines()[0])
    parser.add_argument(
        "--new-credentials",
        action="store_true",
        help="replace saved PIA login and token",
    )
    args = parser.parse_args()
    if os.geteuid() != 0:
        print(
            "Saving a system VPN profile requires your laptop's sudo password.",
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
        setup(args.new_credentials)


if __name__ == "__main__":
    try:
        main()
    except SetupError as error:
        sys.exit(str(error))
    except (KeyError, TypeError, ValueError, binascii.Error):
        sys.exit(
            "PIA returned unexpected data, or the saved credentials are invalid. No connection was started."
        )
    except (OSError, subprocess.TimeoutExpired):
        sys.exit(
            "Setup could not finish a network, command, or file operation. No connection was started."
        )
    except (KeyboardInterrupt, EOFError):
        sys.exit("Setup cancelled.")
