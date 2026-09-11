{
  lib,
  fetchurl,
  writeText,
  writeShellScript,
  writeShellScriptBin,
  makeDesktopItem,
  symlinkJoin,
  python3,
  curl,
  networkmanager,
  wireguard-tools,
  runCommand,
}:
let
  # PIA's server CA, pinned to the manual-connections revision used to review
  # the authentication flow. No credentials are evaluated or built by Nix.
  certificate = fetchurl {
    url = "https://raw.githubusercontent.com/pia-foss/manual-connections/a1412dbe2ca41edbb79c766bc475335cb6cb13ad/ca.rsa.4096.crt";
    hash = "sha256-Mumx0UM+qXYU8qFMbjWOP1fAVwzJ9rLugSaZumlsZqs=";
  };
  helper = writeText "pia-setup.py" (
    builtins.replaceStrings
      [ "@curl@" "@nmcli@" "@wg@" "@certificate@" ]
      [ "${curl}/bin/curl" "${networkmanager}/bin/nmcli" "${wireguard-tools}/bin/wg" "${certificate}" ]
      (builtins.readFile ./pia_setup.py)
  );
  command = writeShellScriptBin "pia-setup" ''
    exec ${python3}/bin/python3 -I ${helper} "$@"
  '';
  launcher = writeShellScript "pia-setup-window" ''
    setup_status=0
    ${command}/bin/pia-setup "$@" || setup_status=$?
    printf '\nPress Enter to close this window…'
    read -r _ || true
    exit "$setup_status"
  '';
  desktopItem = makeDesktopItem {
    name = "pia-setup";
    desktopName = "PIA Setup";
    comment = "Set up or refresh your saved PIA Dedicated VPN connection";
    exec = "${launcher}";
    icon = "network-vpn";
    terminal = true;
    categories = [
      "Network"
      "Settings"
    ];
    keywords = [
      "PIA"
      "VPN"
      "Dedicated IP"
      "Refresh"
    ];
  };
in
symlinkJoin {
  name = "pia-setup";
  paths = [
    command
    desktopItem
  ];
  meta = {
    description = "Prepare a PIA dedicated-IP connection for Noctalia and NetworkManager";
    mainProgram = "pia-setup";
    platforms = lib.platforms.linux;
  };
  passthru.tests.offline = runCommand "pia-setup-offline-tests" { } ''
    export PIA_SETUP_MODULE=${helper}
    ${python3}/bin/python3 ${./test_pia_setup.py}
    touch "$out"
  '';
}
