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
  sigaSessionTemplate = ./sessions/siga/session.template.json;
  sigaSessionSeed = pkgs.runCommand "herdr-siga-session.seed.json" { } ''
    substitute ${sigaSessionTemplate} "$out" \
      --replace-fail "@HOME@" "${config.home.homeDirectory}"
  '';
  sigaProjectDir = ./sessions/siga/projects;
  herdrPlusProjectFiles =
    lib.filterAttrs
      (name: type: type == "regular" && lib.hasSuffix ".toml" name)
      (builtins.readDir sigaProjectDir);
  herdrPlusProjectNames = builtins.attrNames herdrPlusProjectFiles;
  herdrPlusProjectPath = name: sigaProjectDir + "/${name}";
  herdrPlusProjectConfigFiles =
    lib.listToAttrs
      (map
        (name:
          lib.nameValuePair
            "herdr/plugins/config/${herdrPlusPluginId}/projects/${name}"
            { source = herdrPlusProjectPath name; })
        herdrPlusProjectNames);
  herdrSiga = pkgs.writeShellScriptBin "herdr-siga" ''
    set -eu

    export PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.jq ]}:$PATH"

    herdr_bin="${herdrPackage}/bin/herdr"
    session_name="herdr-siga"
    config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/herdr"
    session_dir="$config_dir/sessions/$session_name"
    seed_file="${sigaSessionSeed}"
    log_file="/tmp/herdr-siga-server.log"
    reset=0
    action="start"

    usage() {
      printf '%s\n' "usage: herdr-siga [--reset|--stop|--status]"
      printf '%s\n' "Starts or attaches to the configured Herdr SIGA session."
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
        printf 'Saved Herdr session layout is missing required SIGA panes; re-seeding from Nix template.\n' >&2
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

        has_pane("w1"; 2)
        and has_pane("w1"; 8)
        and has_pane("w3"; 3)
        and has_pane("w3"; 4)
        and has_pane("w4"; 1)
        and has_pane("w4"; 4)
        and has_pane("w5"; 1)
        and has_tab("w1"; 2)
        and has_tab("w3"; 5)
        and has_tab("w4"; 4)
        and has_tab("w5"; 1)
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
      run_in_shell_pane w1:p2 "nvim ."
      run_in_shell_pane w1:p8 "codex"
      run_in_shell_pane w3:p3 "nvim ."
      run_in_shell_pane w3:p4 "codex"
      run_in_shell_pane w4:p1 "nvim ."
      run_in_shell_pane w4:p4 "codex"
      run_in_shell_pane w5:p1 "nvim ."

      herdr_session tab focus w1:t2 >/dev/null
      herdr_session tab focus w3:t5 >/dev/null
      herdr_session tab focus w5:t1 >/dev/null
      herdr_session tab focus w4:t4 >/dev/null
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
in
{
  assertions = [
    {
      assertion = builtins.isAttrs (builtins.fromTOML (builtins.readFile herdrConfig));
      message = "home/modules/herdr/config.toml must be valid TOML.";
    }
    {
      assertion =
        builtins.isAttrs
          (builtins.fromJSON
            (builtins.replaceStrings
              [ "@HOME@" ]
              [ config.home.homeDirectory ]
              (builtins.readFile sigaSessionTemplate)));
      message = "home/modules/herdr/sessions/siga/session.template.json must be valid JSON after @HOME@ substitution.";
    }
  ] ++ map
    (name: {
      assertion = builtins.isAttrs (builtins.fromTOML (builtins.readFile (herdrPlusProjectPath name)));
      message = "home/modules/herdr/sessions/siga/projects/${name} must be valid TOML.";
    })
    herdrPlusProjectNames;

  xdg.configFile = {
    "herdr/config.toml".source = herdrConfig;
  } // herdrPlusProjectConfigFiles;

  home.activation.cleanupLegacyHerdrConfig = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    herdr_config="${config.xdg.configHome}/herdr/config.toml"
    herdr_siga_session_dir="${config.xdg.configHome}/herdr/sessions/herdr-siga"
    legacy_siga_session_dir="${config.xdg.configHome}/herdr/sessions/siga"

    if [ -L "$herdr_config" ]; then
      run rm -f "$herdr_config"
    fi

    run rm -f "$herdr_siga_session_dir/session.seed.json"
    run rm -f "$legacy_siga_session_dir/session.seed.json"
  '';

  home.packages = [
    herdrPackage
    herdrSiga
  ];

}
