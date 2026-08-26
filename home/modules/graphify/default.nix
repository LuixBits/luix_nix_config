{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    getExe
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.programs.graphify;
  graphifyVersion = "0.9.48";
  graphifySource = pkgs.fetchFromGitHub {
    owner = "Graphify-Labs";
    repo = "graphify";
    rev = "v${graphifyVersion}";
    hash = "sha256-gcQ8isXZQu/VQkK74vAaOKnbNdsxiez+TSZdRUxEMiA=";
  };
  graphifyCache = "${config.xdg.cacheHome}/graphify/${graphifyVersion}";

  mkGraphifyCommand =
    command:
    pkgs.writeShellScriptBin command ''
      set -eu

      source_root=${lib.escapeShellArg "${graphifyCache}/source"}
      source_parent=${lib.escapeShellArg graphifyCache}
      ${pkgs.coreutils}/bin/mkdir -p "$source_parent"

      (
        ${pkgs.util-linux}/bin/flock 9
        if [ ! -f "$source_root/.nix-source-ready" ]; then
          source_tmp="$(${pkgs.coreutils}/bin/mktemp -d "$source_parent/source.XXXXXX")"
          trap '${pkgs.coreutils}/bin/rm -rf "$source_tmp"' EXIT
          ${pkgs.coreutils}/bin/cp -R ${graphifySource}/. "$source_tmp/"
          ${pkgs.coreutils}/bin/chmod -R u+w "$source_tmp"
          ${pkgs.coreutils}/bin/touch "$source_tmp/.nix-source-ready"
          ${pkgs.coreutils}/bin/mv "$source_tmp" "$source_root"
          trap - EXIT
        fi
      ) 9>"$source_parent/source.lock"

      export UV_PROJECT_ENVIRONMENT=${lib.escapeShellArg "${graphifyCache}/venv"}
      export UV_CACHE_DIR=${lib.escapeShellArg "${graphifyCache}/uv"}
      export UV_LINK_MODE=copy
      export UV_PYTHON=${pkgs.python312}/bin/python3
      export UV_PYTHON_DOWNLOADS=never

      exec ${getExe pkgs.uv} run \
        --project "$source_root" \
        --locked \
        --no-editable \
        --no-dev \
        --extra mcp \
        ${command} "$@"
    '';

  graphifyPackage = pkgs.symlinkJoin {
    name = "graphify-${graphifyVersion}";
    paths = [
      (mkGraphifyCommand "graphify")
      (mkGraphifyCommand "graphify-mcp")
    ];
    meta = {
      description = "Pinned Graphify CLI and MCP server";
      homepage = "https://github.com/Graphify-Labs/graphify";
      license = lib.licenses.asl20;
      mainProgram = "graphify";
      platforms = pkgs.python312.meta.platforms;
    };
  };

  configuredProjects = lib.concatMapStringsSep "\n" (
    path: "    ${lib.escapeShellArg path}"
  ) cfg.projectRoots;

  graphifyProject = pkgs.writeShellApplication {
    name = "graphify-project";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.jq
    ];
    text = ''
            set -euo pipefail

            configured_projects=(
      ${configuredProjects}
            )

            usage() {
              printf '%s\n' \
                'Usage: graphify-project build [path]' \
                '       graphify-project update [path]' \
                '       graphify-project status [path]' \
                '       graphify-project all' \
                '       graphify-project global'
            }

            project_root() {
              local candidate="''${1:-.}"
              if [ ! -d "$candidate" ]; then
                printf 'Graphify project path is not a directory: %s\n' "$candidate" >&2
                return 1
              fi

              if git -C "$candidate" rev-parse --show-toplevel >/dev/null 2>&1; then
                git -C "$candidate" rev-parse --show-toplevel
              else
                realpath "$candidate"
              fi
            }

            build_project() {
              local root tag
              local -a extra_args=()
              root="$(project_root "$1")"
              tag="$(basename "$root")"

              if [ -f "$root/Cargo.toml" ]; then
                extra_args+=(--cargo)
              fi

              ${cfg.package}/bin/graphify extract "$root" \
                --code-only \
                --global \
                --as "$tag" \
                "''${extra_args[@]}"
            }

            update_project() {
              local root tag graph
              root="$(project_root "$1")"
              tag="$(basename "$root")"
              graph="$root/graphify-out/graph.json"

              if [ ! -f "$graph" ]; then
                build_project "$root"
                return
              fi

              ${cfg.package}/bin/graphify update "$root"
              ${cfg.package}/bin/graphify global add "$graph" --as "$tag"
            }

            status_project() {
              local root graph
              root="$(project_root "$1")"
              graph="$root/graphify-out/graph.json"

              if [ ! -f "$graph" ]; then
                printf '%s: no graph\n' "$root"
                return
              fi

              jq -r --arg root "$root" '
                ($root + ": nodes=" + ((.nodes // []) | length | tostring)
                  + " edges=" + ((.links // .edges // []) | length | tostring))
              ' "$graph"
            }

            command="''${1:-}"
            case "$command" in
              build)
                build_project "''${2:-.}"
                ;;
              update)
                update_project "''${2:-.}"
                ;;
              status)
                status_project "''${2:-.}"
                ;;
              all)
                if [ "''${#configured_projects[@]}" -eq 0 ]; then
                  printf 'No Graphify project roots are configured for this host.\n' >&2
                  exit 1
                fi
                for project in "''${configured_projects[@]}"; do
                  if [ -d "$project" ]; then
                    update_project "$project"
                  else
                    printf 'Skipping missing Graphify project: %s\n' "$project" >&2
                  fi
                done
                ;;
              global)
                ${cfg.package}/bin/graphify global list
                ;;
              -h|--help|help)
                usage
                ;;
              *)
                usage >&2
                exit 2
                ;;
            esac
    '';
  };

  graphifyAll = pkgs.writeShellScriptBin "graphify-all" ''
    exec ${graphifyProject}/bin/graphify-project all "$@"
  '';

  graphifyMcpCommandToml = builtins.toJSON "${cfg.package}/bin/graphify-mcp";
  graphifyGlobalPathToml = builtins.toJSON cfg.globalGraphPath;
  writeCodexGraphifyMcp = pkgs.writeShellScript "write-codex-graphify-mcp" ''
    set -eu

    config_file="$1"
    tmp_file="$config_file.tmp.$$"
    trap '${pkgs.coreutils}/bin/rm -f "$tmp_file"' EXIT

    ${pkgs.gawk}/bin/awk '
      BEGIN { skip_graphify = 0 }
      /^[[:space:]]*\[mcp_servers[.]graphify([.][^]]*)?\][[:space:]]*$/ {
        skip_graphify = 1
        next
      }
      skip_graphify && /^[[:space:]]*\[/ { skip_graphify = 0 }
      !skip_graphify { print }
    ' "$config_file" > "$tmp_file"

    ${pkgs.coreutils}/bin/printf '%s\n' \
      "" \
      '[mcp_servers.graphify]' \
      ${lib.escapeShellArg "command = ${graphifyMcpCommandToml}"} \
      ${lib.escapeShellArg "args = [${graphifyGlobalPathToml}]"} \
      'enabled_tools = ["query_graph", "get_node", "get_neighbors", "shortest_path", "get_community", "god_nodes", "graph_stats"]' \
      'startup_timeout_sec = 300' \
      'tool_timeout_sec = 120' \
      >> "$tmp_file"

    ${pkgs.coreutils}/bin/mv "$tmp_file" "$config_file"
    ${pkgs.coreutils}/bin/chmod 0600 "$config_file"
    trap - EXIT
  '';
in
{
  options.programs.graphify = {
    enable = mkEnableOption "Graphify code knowledge graphs for coding agents";

    package = mkOption {
      type = types.package;
      default = graphifyPackage;
      defaultText = "Graphify 0.9.48 executed from its locked uv environment";
      description = "Package providing the `graphify` and `graphify-mcp` executables.";
    };

    projectRoots = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Project roots refreshed by `graphify-all`. Missing paths are skipped.";
    };

    globalGraphPath = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.graphify/global-graph.json";
      defaultText = "~/.graphify/global-graph.json";
      description = "Merged cross-project graph used as the MCP server's default graph.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      cfg.package
      graphifyProject
      graphifyAll
    ];

    home.file.".agents/skills/graphify/SKILL.md" = {
      source = ./skill/SKILL.md;
      force = true;
    };

    home.activation.ensureGraphifyAgentIntegrations =
      lib.hm.dag.entryAfter [ "ensureCodexConfig" "ensureHerdrAgentIntegrations" ]
        ''
          codex_dir="${config.home.homeDirectory}/.codex"
          codex_config="$codex_dir/config.toml"
          kimi_dir="${config.home.homeDirectory}/.kimi-code"
          kimi_config="$kimi_dir/mcp.json"
          kimi_tmp="$kimi_config.tmp.$$"

          run mkdir -p "$codex_dir" "$kimi_dir"

          if [ ! -e "$codex_config" ]; then
            run install -m 0600 /dev/null "$codex_config"
          fi
          run ${writeCodexGraphifyMcp} "$codex_config"

          if [ -s "$kimi_config" ]; then
            run ${pkgs.jq}/bin/jq \
              --arg command "${cfg.package}/bin/graphify-mcp" \
            --arg graph "${cfg.globalGraphPath}" \
            '.mcpServers = ((.mcpServers // {}) + {
              graphify: {
                command: $command,
                args: [$graph],
                enabledTools: [
                  "query_graph",
                  "get_node",
                  "get_neighbors",
                  "shortest_path",
                  "get_community",
                  "god_nodes",
                  "graph_stats"
                ],
                startupTimeoutMs: 300000,
                toolTimeoutMs: 120000
              }
            })' \
              "$kimi_config" > "$kimi_tmp"
          else
            run ${pkgs.jq}/bin/jq -n \
              --arg command "${cfg.package}/bin/graphify-mcp" \
            --arg graph "${cfg.globalGraphPath}" \
            '{mcpServers: {
              graphify: {
                command: $command,
                args: [$graph],
                enabledTools: [
                  "query_graph",
                  "get_node",
                  "get_neighbors",
                  "shortest_path",
                  "get_community",
                  "god_nodes",
                  "graph_stats"
                ],
                startupTimeoutMs: 300000,
                toolTimeoutMs: 120000
              }
            }}' \
              > "$kimi_tmp"
          fi
          run chmod 0600 "$kimi_tmp"
          run mv "$kimi_tmp" "$kimi_config"
        '';
  };
}
