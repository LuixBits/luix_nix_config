{ config, inputs, lib, pkgs, ... }:
let
  herdrPackage = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
  herdrConfig = ./config.toml;
  herdrPlusPluginId = "cloudmanic.herdr-plus";
  herdrPlusVersion = "0.1.10";
  herdrPlusSrc = pkgs.fetchFromGitHub {
    owner = "cloudmanic";
    repo = "herdr-plus";
    rev = "013fe1667a638487004164955a01707584ab7b9e";
    hash = "sha256-doOEYixyTb5t2cX0kfK/8swXqTYcpF14jdegOPgAMJs=";
  };
  herdrPlus = pkgs.buildGoModule {
    pname = "herdr-plus";
    version = herdrPlusVersion;
    src = herdrPlusSrc;
    vendorHash = "sha256-im2gPhLarMf1w/8rhxbOe9EhUdvseffukT9tqU4EEXI=";
  };
  herdrPlusPlugin = pkgs.runCommand "herdr-plus-plugin-${herdrPlusVersion}" { } ''
    mkdir -p "$out"
    cp -R ${herdrPlusSrc}/. "$out/"
    install -D -m 0755 ${herdrPlus}/bin/herdr-plus "$out/bin/herdr-plus"
  '';
  sessionSeed = sessionName: sessionTemplate:
    pkgs.runCommand "${sessionName}-session.seed.json" { } ''
      substitute ${sessionTemplate} "$out" \
        --replace-fail "@HOME@" "${config.home.homeDirectory}"
    '';
  mkPaneCheck = { workspace, pane }: ''has_pane("${workspace}"; ${toString pane})'';
  mkTabCheck = { workspace, tab }: ''has_tab("${workspace}"; ${toString tab})'';
  mkHerdrSession =
    { commandName
    , sessionName
    , description
    , sessionTemplate
    , requiredPanes
    , requiredTabs
    , bootstrapCommands
    , focusTabs
    , ...
    }:
    let
      seed = sessionSeed sessionName sessionTemplate;
      compatibilityChecks =
        lib.concatStringsSep "\n        and "
          ((map mkPaneCheck requiredPanes) ++ (map mkTabCheck requiredTabs));
      bootstrapShell =
        lib.concatStringsSep "\n      "
          (map
            ({ pane, command }:
              "run_in_shell_pane ${lib.escapeShellArg pane} ${lib.escapeShellArg command}")
            bootstrapCommands);
      focusShell =
        lib.concatStringsSep "\n      "
          (map
            (tab: "herdr_session tab focus ${lib.escapeShellArg tab} >/dev/null")
            focusTabs);
    in
    pkgs.writeShellScriptBin commandName ''
    set -eu

    export PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.jq ]}:$PATH"

    herdr_bin="${herdrPackage}/bin/herdr"
    session_name="${sessionName}"
    config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/herdr"
    session_dir="$config_dir/sessions/$session_name"
    seed_file="${seed}"
    log_file="/tmp/${sessionName}-server.log"
    reset=0
    action="start"

    usage() {
      printf '%s\n' "usage: ${commandName} [--reset|--stop|--status]"
      printf '%s\n' "${description}"
      printf '%s\n' "  --reset   stop and delete the saved session before starting"
      printf '%s\n' "  --stop    stop the session"
      printf '%s\n' "  --status  show the workspace list"
    }

    case "''${1:-}" in
      "")
        ;;
      "--reset")
        reset=1
        ;;
      "--stop")
        action="stop"
        ;;
      "--status")
        action="status"
        ;;
      "-h"|"--help")
        usage
        exit 0
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac

    herdr_session() {
      "$herdr_bin" --session "$session_name" "$@"
    }

    is_running() {
      herdr_session workspace list >/dev/null 2>&1
    }

    stop_session() {
      "$herdr_bin" session stop "$session_name" --json >/dev/null 2>&1 || true
      for _ in $(seq 1 100); do
        if ! is_running; then
          return 0
        fi
        sleep 0.1
      done
      printf 'Herdr session did not stop: %s\n' "$session_name" >&2
      exit 1
    }

    delete_session() {
      "$herdr_bin" session delete "$session_name" --json >/dev/null 2>&1 || true
    }

    seed_session() {
      mkdir -p "$session_dir"
      rm -f "$session_dir/session.seed.json"
      if [ "$reset" -eq 1 ] || [ ! -e "$session_dir/session.json" ]; then
        install -m 0644 "$seed_file" "$session_dir/session.json"
      elif ! saved_session_is_compatible; then
        backup_file="$session_dir/session.json.bak.$(date +%Y%m%d%H%M%S)"
        cp -p "$session_dir/session.json" "$backup_file"
        printf 'Saved Herdr session layout is missing required panes; re-seeding from Nix template.\n' >&2
        printf 'Previous session saved at: %s\n' "$backup_file" >&2
        install -m 0644 "$seed_file" "$session_dir/session.json"
      fi
    }

    saved_session_is_compatible() {
      jq -e '
        def has_pane($workspace; $pane):
          [ .workspaces[]? | select(.id == $workspace) | (.public_pane_numbers // {})[] ]
          | index($pane) != null;
        def has_tab($workspace; $tab):
          [ .workspaces[]? | select(.id == $workspace) | (.public_tab_numbers // [])[] ]
          | index($tab) != null;

        ${compatibilityChecks}
      ' "$session_dir/session.json" >/dev/null 2>&1
    }

    start_session() {
      herdr_session server >"$log_file" 2>&1 &
      for _ in $(seq 1 100); do
        if is_running; then
          return 0
        fi
        sleep 0.1
      done
      printf 'Herdr session did not start: %s\n' "$session_name" >&2
      printf 'See log: %s\n' "$log_file" >&2
      exit 1
    }

    link_plugin() {
      herdr_session plugin link "${herdrPlusPlugin}" >/dev/null
    }

    wait_for_pane() {
      pane_id="$1"
      for _ in $(seq 1 100); do
        if herdr_session pane get "$pane_id" >/dev/null 2>&1; then
          return 0
        fi
        sleep 0.1
      done
      printf 'pane did not appear: %s\n' "$pane_id" >&2
      exit 1
    }

    run_in_shell_pane() {
      pane_id="$1"
      command="$2"
      wait_for_pane "$pane_id"

      process_info="$(herdr_session pane process-info --pane "$pane_id" 2>/dev/null || true)"
      if printf '%s\n' "$process_info" | jq -e '
        .result.process_info.foreground_processes as $processes
        | ($processes | length) == 1
        and (
          [
            ($processes[0].name // ""),
            ($processes[0].argv[0] // "")
          ]
          | any(test("(^|/|\\.)(bash|zsh|fish|sh)$|^(bash|zsh|fish|sh)$"))
        )
      ' >/dev/null; then
        herdr_session pane run "$pane_id" "$command" >/dev/null
      fi
    }

    bootstrap_commands() {
      ${bootstrapShell}
      ${focusShell}
    }

    if [ "$action" = "stop" ]; then
      if is_running; then
        stop_session
        printf '%s\n' "Herdr session '$session_name' stopped."
      else
        printf '%s\n' "Herdr session '$session_name' is not running."
      fi
      exit 0
    fi

    if [ "$action" = "status" ]; then
      if is_running; then
        herdr_session workspace list
      else
        printf '%s\n' "Herdr session '$session_name' is not running." >&2
        exit 1
      fi
      exit 0
    fi

    seed_session

    if is_running; then
      if [ "$reset" -eq 1 ]; then
        stop_session
      else
        link_plugin
        bootstrap_commands
        exec "$herdr_bin" --session "$session_name"
      fi
    fi

    if [ "$reset" -eq 1 ]; then
      delete_session
      seed_session
    fi

    start_session
    link_plugin
    bootstrap_commands

    printf '%s\n' "Herdr session '$session_name' is ready."
    printf '%s\n' "herdr-plus is linked from Nix: ${herdrPlusPlugin}"
    exec "$herdr_bin" --session "$session_name"
  '';
  herdrSessions = [
    {
      commandName = "herdr-siga";
      sessionName = "herdr-siga";
      description = "Starts or attaches to the configured Herdr SIGA session.";
      sessionTemplate = ./sessions/siga/session.template.json;
      projectDirs = [ ./sessions/siga/projects ];
      requiredPanes = [
        { workspace = "w1"; pane = 2; }
        { workspace = "w1"; pane = 8; }
        { workspace = "w3"; pane = 3; }
        { workspace = "w3"; pane = 4; }
        { workspace = "w4"; pane = 1; }
        { workspace = "w4"; pane = 4; }
        { workspace = "w5"; pane = 1; }
      ];
      requiredTabs = [
        { workspace = "w1"; tab = 2; }
        { workspace = "w3"; tab = 5; }
        { workspace = "w4"; tab = 4; }
        { workspace = "w5"; tab = 1; }
      ];
      bootstrapCommands = [
        { pane = "w1:p2"; command = "nvim ."; }
        { pane = "w1:p8"; command = "codex-new"; }
        { pane = "w3:p3"; command = "nvim ."; }
        { pane = "w3:p4"; command = "codex-new"; }
        { pane = "w4:p1"; command = "nvim ."; }
        { pane = "w4:p4"; command = "codex-new"; }
        { pane = "w5:p1"; command = "nvim ."; }
      ];
      focusTabs = [ "w1:t2" "w3:t5" "w5:t1" "w4:t4" ];
    }
    {
      commandName = "herdr-luix";
      sessionName = "herdr-luix";
      description = "Starts or attaches to the configured Herdr Luix session.";
      sessionTemplate = ./sessions/luix/session.template.json;
      projectDirs = [ ./sessions/luix/projects ];
      requiredPanes = [
        { workspace = "w1"; pane = 1; }
        { workspace = "w1"; pane = 2; }
        { workspace = "w2"; pane = 1; }
        { workspace = "w2"; pane = 2; }
        { workspace = "w3"; pane = 1; }
        { workspace = "w3"; pane = 2; }
        { workspace = "w4"; pane = 1; }
      ];
      requiredTabs = [
        { workspace = "w1"; tab = 1; }
        { workspace = "w2"; tab = 1; }
        { workspace = "w3"; tab = 1; }
        { workspace = "w4"; tab = 1; }
      ];
      bootstrapCommands = [
        { pane = "w1:p1"; command = "nvim ."; }
        { pane = "w1:p2"; command = "codex-new"; }
        { pane = "w2:p1"; command = "nvim ."; }
        { pane = "w2:p2"; command = "codex-new"; }
        { pane = "w3:p1"; command = "nvim ."; }
        { pane = "w3:p2"; command = "codex-new"; }
        { pane = "w4:p1"; command = "nvim ."; }
      ];
      focusTabs = [ "w1:t1" "w2:t1" "w3:t1" "w4:t1" ];
    }
  ];
  herdrSessionPackages = map mkHerdrSession herdrSessions;
  projectFilesForDir = projectDir:
    let
      projectFiles =
        lib.filterAttrs
          (name: type: type == "regular" && lib.hasSuffix ".toml" name)
          (builtins.readDir projectDir);
    in
    map
      (name: {
        inherit name;
        path = projectDir + "/${name}";
      })
      (builtins.attrNames projectFiles);
  herdrPlusProjects = lib.concatMap (session: lib.concatMap projectFilesForDir session.projectDirs) herdrSessions;
  herdrPlusProjectConfigFiles =
    lib.listToAttrs
      (map
        ({ name, path }:
          lib.nameValuePair
            "herdr/plugins/config/${herdrPlusPluginId}/projects/${name}"
            { source = path; })
        herdrPlusProjects);
in
{
  assertions = [
    {
      assertion = builtins.isAttrs (builtins.fromTOML (builtins.readFile herdrConfig));
      message = "home/modules/herdr/config.toml must be valid TOML.";
    }
  ] ++ map
    (session: {
      assertion =
        builtins.isAttrs
          (builtins.fromJSON
            (builtins.replaceStrings
              [ "@HOME@" ]
              [ config.home.homeDirectory ]
              (builtins.readFile session.sessionTemplate)));
      message = "${session.sessionName} session template must be valid JSON after @HOME@ substitution.";
    })
    herdrSessions
  ++ map
    ({ name, path }: {
      assertion = builtins.isAttrs (builtins.fromTOML (builtins.readFile path));
      message = "Herdr project ${name} must be valid TOML.";
    })
    herdrPlusProjects;

  xdg.configFile = {
    "herdr/config.toml".source = herdrConfig;
  } // herdrPlusProjectConfigFiles;

  home.activation.cleanupLegacyHerdrConfig = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    herdr_config="${config.xdg.configHome}/herdr/config.toml"
    herdr_siga_session_dir="${config.xdg.configHome}/herdr/sessions/herdr-siga"
    herdr_luix_session_dir="${config.xdg.configHome}/herdr/sessions/herdr-luix"
    legacy_siga_session_dir="${config.xdg.configHome}/herdr/sessions/siga"

    if [ -L "$herdr_config" ]; then
      run rm -f "$herdr_config"
    fi

    run rm -f "$herdr_siga_session_dir/session.seed.json"
    run rm -f "$herdr_luix_session_dir/session.seed.json"
    run rm -f "$legacy_siga_session_dir/session.seed.json"
  '';

  home.packages = [ herdrPackage ] ++ herdrSessionPackages;

}
