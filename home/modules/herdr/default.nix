{ config, inputs, lib, pkgs, ... }:
let
  herdrPackage = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
  codexCommand = "${config.programs.codex.package}/bin/codex";
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
  herdrBarVersion = "0.2.1";
  herdrBarSrc = pkgs.fetchFromGitHub {
    owner = "jeffarese";
    repo = "herdr-bar";
    rev = "01cc0620ec743ee7a62a561551b59d9be81bd563";
    hash = "sha256-DXOeCI5LGVfPvxXhACihyH6K9i6/q6uxTQdyYaUkUhE=";
  };
  herdrBarPlugin = pkgs.runCommand "herdr-bar-plugin-${herdrBarVersion}" { } ''
    mkdir -p "$out"
    cp -R ${herdrBarSrc}/. "$out/"
    substituteInPlace "$out/herdr-plugin.toml" \
      --replace-fail \
        'command = ["python3", "run.py"]' \
        'command = ["${pkgs.python3}/bin/python3", "run.py"]'
  '';
  herdrBrowserVersion = "0.1.0";
  herdrBrowserSrc = pkgs.fetchFromGitHub {
    owner = "ogulcancelik";
    repo = "herdr-browser";
    rev = "be6888b71cf4eb5939ee79a746bd1a1c22ade046";
    hash = "sha256-4Dlo4YQpLPJKEPuXSS4EO5LMCmUn/tezEiIqlFXhCxo=";
  };
  herdrBrowserBun = pkgs.writeShellScript "herdr-browser-bun" ''
    export HERDR_BROWSER_CHROME="${pkgs.chromium}/bin/chromium"
    exec ${pkgs.bun}/bin/bun "$@"
  '';
  herdrBrowserPlugin = pkgs.runCommand "herdr-browser-plugin-${herdrBrowserVersion}" { } ''
    mkdir -p "$out"
    cp -R ${herdrBrowserSrc}/. "$out/"
    substituteInPlace "$out/herdr-plugin.toml" \
      --replace-fail \
        'command = ["bun",' \
        'command = ["${herdrBrowserBun}",'
  '';
  herdrBrowserConfig = pkgs.writeText "herdr-browser.json" (builtins.toJSON {
    linkOpenPlacement = "overlay";
    focusOnOpen = true;
    browserZoom = 1.0;
    showDiagnostics = false;
    # Herdr Browser renders Chromium through the Kitty graphics protocol.
    # A 0.75 capture scale cuts the pixel workload substantially on HiDPI
    # displays while keeping development pages readable.
    captureScale = 0.75;
  });
  herdrBrowserTab = pkgs.writeShellScriptBin "herdr-browser-tab" ''
    set -eu

    if [ "$#" -gt 1 ]; then
      printf 'Usage: herdr-browser-tab [initial-url]\n' >&2
      exit 2
    fi

    export HERDR_PLUGIN_ID="official.browser"
    export HERDR_PLUGIN_ROOT="${herdrBrowserPlugin}"
    export HERDR_PLUGIN_CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/herdr/plugins/config/official.browser"
    export HERDR_PLUGIN_STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/herdr/plugins/official.browser"
    export HERDR_BROWSER_CHROME="${pkgs.chromium}/bin/chromium"

    if [ "$#" -eq 1 ]; then
      export HERDR_BROWSER_INITIAL_URL="$1"
    fi

    exec ${herdrBrowserBun} run "${herdrBrowserPlugin}/src/viewer.ts"
  '';
  spaceUsagePluginId = "ez-corp.space-usage";
  spaceUsageVersion = "1.11.1";
  spaceUsageSrc = pkgs.fetchFromGitHub {
    owner = "ezcorp-org";
    repo = "herdr-pc-ram-and-cpu-usage-overlay";
    rev = "fcfb6f7fa0a159adfab4528496bf10dd62e3e7c1";
    hash = "sha256-amiY6b6CQde+KQOt/B1NvYZfYLVql4xsDF5AD/qghcw=";
  };
  spaceUsage = pkgs.rustPlatform.buildRustPackage {
    pname = "herdr-space-usage";
    version = spaceUsageVersion;
    src = spaceUsageSrc;
    cargoLock.lockFile = spaceUsageSrc + "/Cargo.lock";
  };
  spaceUsagePlugin = pkgs.runCommand "herdr-space-usage-plugin-${spaceUsageVersion}" { } ''
    mkdir -p "$out"
    cp -R ${spaceUsageSrc}/. "$out/"
    substituteInPlace "$out/herdr-plugin.toml" \
      --replace-fail \
        $'[[build]]\ncommand = ["cargo", "build", "--release"]\nplatforms = ["linux", "macos", "windows"]' \
        '# The executable is built and pinned by Nix.'
    install -D -m 0755 \
      ${spaceUsage}/bin/space-usage \
      "$out/target/release/space-usage"
  '';
  herdrPlugins = [
    herdrPlusPlugin
    herdrBarPlugin
    herdrBrowserPlugin
    spaceUsagePlugin
  ];
  linkHerdrPluginsShell = lib.concatMapStringsSep "\n      "
    (plugin: "herdr_session plugin link ${lib.escapeShellArg plugin} >/dev/null")
    herdrPlugins;
  linkedHerdrPluginsSummary = lib.concatMapStringsSep "\n    "
    (plugin: "printf '%s\\n' ${lib.escapeShellArg "Herdr plugin linked from Nix: ${plugin}"}")
    herdrPlugins;
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
    , layoutRevision ? null
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
    layout_revision=${lib.escapeShellArg (if layoutRevision == null then "" else layoutRevision)}
    layout_revision_file="$session_dir/layout-revision"
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

    session_needs_reseed() {
      if [ "$reset" -eq 1 ] || [ ! -e "$session_dir/session.json" ]; then
        return 0
      fi

      if [ -n "$layout_revision" ] && { [ ! -e "$layout_revision_file" ] || [ "$(cat "$layout_revision_file")" != "$layout_revision" ]; }; then
        return 0
      fi

      if ! saved_session_is_compatible; then
        return 0
      fi

      return 1
    }

    seed_session() {
      mkdir -p "$session_dir"
      rm -f "$session_dir/session.seed.json"
      if [ "$reset" -eq 1 ] || [ ! -e "$session_dir/session.json" ]; then
        install -m 0644 "$seed_file" "$session_dir/session.json"
      elif [ -n "$layout_revision" ] && { [ ! -e "$layout_revision_file" ] || [ "$(cat "$layout_revision_file")" != "$layout_revision" ]; }; then
        backup_file="$session_dir/session.json.bak.$(date +%Y%m%d%H%M%S)"
        cp -p "$session_dir/session.json" "$backup_file"
        printf 'Configured Herdr layout changed; re-seeding from the Nix template.\n' >&2
        printf 'Previous session saved at: %s\n' "$backup_file" >&2
        install -m 0644 "$seed_file" "$session_dir/session.json"
      elif ! saved_session_is_compatible; then
        backup_file="$session_dir/session.json.bak.$(date +%Y%m%d%H%M%S)"
        cp -p "$session_dir/session.json" "$backup_file"
        printf 'Saved Herdr session layout is missing required panes; re-seeding from Nix template.\n' >&2
        printf 'Previous session saved at: %s\n' "$backup_file" >&2
        install -m 0644 "$seed_file" "$session_dir/session.json"
      fi

      if [ -n "$layout_revision" ]; then
        printf '%s\n' "$layout_revision" > "$layout_revision_file"
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

    link_plugins() {
      ${linkHerdrPluginsShell}
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

    needs_reseed=0
    if session_needs_reseed; then
      needs_reseed=1
    fi

    if is_running; then
      if [ "$reset" -eq 1 ] || [ "$needs_reseed" -eq 1 ]; then
        if [ "$reset" -eq 0 ]; then
          printf 'Restarting the running Herdr session to apply the configured layout.\n' >&2
        fi
        stop_session
      else
        link_plugins
        bootstrap_commands
        exec "$herdr_bin" --session "$session_name"
      fi
    fi

    if [ "$reset" -eq 1 ]; then
      delete_session
    fi

    seed_session
    start_session
    link_plugins
    bootstrap_commands

    printf '%s\n' "Herdr session '$session_name' is ready."
    ${linkedHerdrPluginsSummary}
    exec "$herdr_bin" --session "$session_name"
  '';
  herdrSessions = [
    {
      commandName = "herdr-siga";
      sessionName = "herdr-siga";
      description = "Starts or attaches to the configured Herdr SIGA session.";
      sessionTemplate = ./sessions/siga/session.template.json;
      layoutRevision = builtins.hashString "sha256" (
        (builtins.readFile ./sessions/siga/session.template.json)
        + "\nbootstrap-agent-command=codex\n"
      );
      projectDirs = [ ./sessions/siga/projects ];
      requiredTabs = lib.concatMap
        (workspace: map (tab: { inherit workspace tab; }) [ 1 2 3 ])
        [ "w1" "w3" "w4" "w5" ]
        ++ map (workspace: { inherit workspace; tab = 4; }) [ "w1" "w3" ];
      requiredPanes = lib.concatMap
        (workspace: map (pane: { inherit workspace pane; }) [ 1 2 3 ])
        [ "w1" "w3" "w4" "w5" ]
        ++ map (workspace: { inherit workspace; pane = 4; }) [ "w1" "w3" ];
      bootstrapCommands =
        lib.concatMap
          (workspace: [
            { pane = "${workspace}:p1"; command = "nvim ."; }
            { pane = "${workspace}:p2"; command = codexCommand; }
          ])
          [ "w1" "w3" "w4" "w5" ]
        ++ [
          { pane = "w1:p4"; command = "${herdrBrowserTab}/bin/herdr-browser-tab https://roi.local"; }
          { pane = "w3:p4"; command = "${herdrBrowserTab}/bin/herdr-browser-tab https://siga-webshop.local/ch-de"; }
        ];
      # Select every workspace's Neovim tab and finish on Roiguard.
      focusTabs = [ "w5:t1" "w4:t1" "w3:t1" "w1:t1" ];
    }
    {
      commandName = "herdr-luix";
      sessionName = "herdr-luix";
      description = "Starts or attaches to the configured Herdr Luix session.";
      sessionTemplate = ./sessions/luix/session.template.json;
      layoutRevision = builtins.hashString "sha256" (
        (builtins.readFile ./sessions/luix/session.template.json)
        + "\nbootstrap-agent-command=codex\n"
      );
      projectDirs = [ ./sessions/luix/projects ];
      requiredTabs = lib.concatMap
        (workspace: map (tab: { inherit workspace tab; }) [ 1 2 3 4 ])
        [ "w1" "w2" "w3" "w4" "w5" ]
        ++ map (workspace: { inherit workspace; tab = 5; }) [ "w1" "w4" "w5" ];
      requiredPanes = lib.concatMap
        (workspace: map (pane: { inherit workspace pane; }) [ 1 2 3 4 ])
        [ "w1" "w2" "w3" "w4" "w5" ]
        ++ map (workspace: { inherit workspace; pane = 5; }) [ "w1" "w4" "w5" ];
      bootstrapCommands =
        lib.concatMap
          (workspace: [
            { pane = "${workspace}:p1"; command = "nvim ."; }
            { pane = "${workspace}:p2"; command = codexCommand; }
            { pane = "${workspace}:p3"; command = "kimi"; }
          ])
          [ "w1" "w2" "w3" "w4" "w5" ]
        ++ [
          { pane = "w1:p5"; command = "${herdrBrowserTab}/bin/herdr-browser-tab"; }
          { pane = "w4:p5"; command = "${herdrBrowserTab}/bin/herdr-browser-tab"; }
          { pane = "w5:p5"; command = "${herdrBrowserTab}/bin/herdr-browser-tab http://localhost:3000"; }
        ];
      # Select every workspace's Neovim tab and finish on Projects.
      focusTabs = [ "w5:t1" "w4:t1" "w3:t1" "w2:t1" "w1:t1" ];
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
    "herdr/plugins/config/${spaceUsagePluginId}/config.toml".source = ./plugins/space-usage.toml;
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

  home.activation.ensureHerdrWorkspaceDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p \
      "${config.home.homeDirectory}/projects" \
      "${config.home.homeDirectory}/notes" \
      "${config.home.homeDirectory}/projects/LuixBitsRemotion"
  '';

  # Keep the lifecycle/session hooks in sync with the pinned Herdr release.
  # Without this, an older hook can survive a Herdr upgrade indefinitely.
  home.activation.ensureHerdrAgentIntegrations = lib.hm.dag.entryAfter [ "ensureCodexConfig" ] ''
    kimi_config_dir="${config.home.homeDirectory}/.kimi-code"
    run mkdir -p "$kimi_config_dir"

    run ${pkgs.coreutils}/bin/env \
      CODEX_HOME="${config.home.homeDirectory}/.codex" \
      ${herdrPackage}/bin/herdr integration install codex
    run ${pkgs.coreutils}/bin/env \
      KIMI_CODE_HOME="$kimi_config_dir" \
      ${herdrPackage}/bin/herdr integration install kimi
  '';

  # Keep this file writable so Herdr Browser can persist toolbar zoom changes.
  # Rebuilding reapplies the declarative performance-oriented defaults above.
  home.activation.configureHerdrBrowser = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    browser_config_dir="${config.xdg.configHome}/herdr/plugins/config/official.browser"
    run mkdir -p "$browser_config_dir"
    run install -m 0644 ${herdrBrowserConfig} "$browser_config_dir/browser.json"
  '';

  home.packages = [ herdrPackage herdrBrowserTab ] ++ herdrSessionPackages;

}
