{
  lib,
  android-tools,
  makeDesktopItem,
  python3,
  runCommand,
  symlinkJoin,
  systemd,
  wivrn,
  writeShellScript,
  writeShellScriptBin,
  writeText,
  defaultSerial ? null,
}:
let
  helper = writeText "simracing-quest.py" (
    builtins.replaceStrings
      [ "@adb@" "@systemctl@" "@wivrnctl@" "@wivrnVersion@" ]
      [
        "${android-tools}/bin/adb"
        "${systemd}/bin/systemctl"
        "${wivrn}/bin/wivrnctl"
        wivrn.version
      ]
      (builtins.readFile ./quest.py)
  );
  command = writeShellScriptBin "simracing-quest" ''
    exec ${python3}/bin/python3 -I ${helper} \
      ${lib.optionalString (defaultSerial != null) "--serial ${lib.escapeShellArg defaultSerial}"} "$@"
  '';
  window = writeShellScript "simracing-quest-window" ''
    quest_status=0
    ${command}/bin/simracing-quest "$@" || quest_status=$?
    printf '\nPress Enter to close this window…'
    read -r _ || true
    exit "$quest_status"
  '';
  desktop = makeDesktopItem {
    name = "simracing-quest";
    desktopName = "Simracing — Connect Quest USB";
    comment = "Connect a Meta Quest to WiVRn over USB for BeamNG.drive";
    exec = "${window}";
    icon = "input-gaming";
    terminal = true;
    categories = [ "Game" ];
    keywords = [
      "Quest"
      "VR"
      "WiVRn"
      "BeamNG"
      "Simracing"
    ];
  };
in
symlinkJoin {
  name = "simracing-quest";
  paths = [
    command
    desktop
  ];
  meta = {
    description = "Connect an authorized Meta Quest to WiVRn through USB";
    mainProgram = "simracing-quest";
    platforms = lib.platforms.linux;
  };
  passthru.tests.offline = runCommand "simracing-quest-offline-tests" { } ''
    export SIMRACING_QUEST_MODULE=${helper}
    ${python3}/bin/python3 ${./test_quest.py}
    touch "$out"
  '';
}
