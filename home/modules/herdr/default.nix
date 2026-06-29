{ config, inputs, lib, pkgs, ... }:
let
  herdrPackage = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
  herdrConfig = ./config.toml;
  sigaSessionTemplate = ./sessions/siga/session.template.json;
  sigaSessionSeed = pkgs.runCommand "herdr-siga-session.seed.json" { } ''
    substitute ${sigaSessionTemplate} "$out" \
      --replace-fail "@HOME@" "${config.home.homeDirectory}"
  '';
  herdrSigaSession = pkgs.writeShellScriptBin "herdr-siga-session" ''
    set -eu

    export PATH="${lib.makeBinPath [ pkgs.coreutils ]}:$PATH"

    herdr_bin="${herdrPackage}/bin/herdr"
    session_name="siga"
    config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/herdr"
    session_dir="$config_dir/sessions/$session_name"
    seed_file="${sigaSessionSeed}"
    reset=0

    usage() {
      printf '%s\n' "usage: herdr-siga-session [--reset]"
      printf '%s\n' "Seeds the declared Herdr session named 'siga' and starts nvim/codex panes."
      printf '%s\n' "Use --reset to stop an already running siga Herdr session first."
    }

    case "''${1:-}" in
      "")
        ;;
      "--reset")
        reset=1
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

    mkdir -p "$session_dir"
    rm -f "$session_dir/session.seed.json"
    ln -s "$seed_file" "$session_dir/session.seed.json"

    server_running=0
    if herdr_session workspace list >/dev/null 2>&1; then
      server_running=1
    fi

    if [ "$server_running" -eq 1 ] && [ "$reset" -ne 1 ]; then
      printf '%s\n' "Herdr session 'siga' is already running. Re-run with --reset to stop and recreate it." >&2
      exit 2
    fi

    if [ "$server_running" -eq 1 ]; then
      "$herdr_bin" session stop "$session_name" --json >/dev/null 2>&1 || true
      for _ in $(seq 1 100); do
        if ! herdr_session workspace list >/dev/null 2>&1; then
          break
        fi
        sleep 0.1
      done
    fi

    install -m 0644 "$seed_file" "$session_dir/session.json"
    herdr_session server >/tmp/herdr-siga-session-server.log 2>&1 &

    for _ in $(seq 1 100); do
      if herdr_session workspace list >/dev/null 2>&1; then
        break
      fi
      sleep 0.1
    done

    herdr_session workspace list >/dev/null

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

    run_in_pane() {
      pane_id="$1"
      command="$2"
      wait_for_pane "$pane_id"
      herdr_session pane run "$pane_id" "$command" >/dev/null
    }

    run_in_pane w1:p2 "nvim ."
    run_in_pane w1:p8 "codex"
    run_in_pane w3:p3 "nvim ."
    run_in_pane w3:p4 "codex"
    run_in_pane w4:p1 "nvim ."
    run_in_pane w4:p4 "codex"
    run_in_pane w5:p1 "nvim ."

    herdr_session tab focus w1:t2 >/dev/null
    herdr_session tab focus w3:t5 >/dev/null
    herdr_session tab focus w5:t1 >/dev/null
    herdr_session tab focus w4:t4 >/dev/null

    printf '%s\n' "Herdr session 'siga' is ready. Attach with: herdr --session siga"
    printf '%s\n' "If herdr-plus is not installed in this named session yet, run: herdr --session siga plugin install cloudmanic/herdr-plus --yes"
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
  ];

  home.packages = [
    herdrPackage
    herdrSigaSession
  ];

  home.activation.ensureHerdrConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    herdr_dir="${config.xdg.configHome}/herdr"
    config_file="$herdr_dir/config.toml"
    session_dir="$herdr_dir/sessions/siga"

    run mkdir -p "$herdr_dir"
    run rm -f "$config_file"
    run ln -s ${herdrConfig} "$config_file"

    run mkdir -p "$session_dir"
    run rm -f "$session_dir/session.seed.json"
    run ln -s ${sigaSessionSeed} "$session_dir/session.seed.json"

    if [ ! -S "$session_dir/herdr.sock" ] && [ ! -e "$session_dir/session.json" ]; then
      run install -m 0644 ${sigaSessionSeed} "$session_dir/session.json"
    fi
  '';

  home.activation.herdrPostInstallNote = lib.hm.dag.entryAfter [ "ensureHerdrConfig" ] ''
    echo "Herdr post-install:"
    echo "  herdr integration install codex"
    echo "  herdr integration status"
    echo "  herdr-siga-session --reset"
    echo "  herdr --session siga plugin install cloudmanic/herdr-plus --yes"
    echo "  herdr --session siga"
  '';
}
