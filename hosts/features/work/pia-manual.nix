{ config, pkgs, lib, ... }:

# Super simple PIA automation: load ~/.env style credentials, ensure the
# manual-connections scripts exist (download from GitHub if missing) and run
# run_setup.sh during every `nixos-rebuild switch`. No long-running service, no
# extra state – just script execution exactly like doing it by hand.

let
  defaultEnvFile = "/run/secrets/pia.env";
  defaultWorkDir = "/var/lib/pia-manual";
  defaultScriptDirectory = "${defaultWorkDir}/manual-connections";
  defaultScriptName = "run_setup.sh";
  repoUrl = "https://codeload.github.com/pia-foss/manual-connections/tar.gz/refs/heads/master";
  runtimePath =
    lib.makeBinPath (with pkgs; [
      bash
      coreutils
      curl
      findutils
      gnugrep
      gnused
      gnutar
      gzip
      gawk
      ncurses
      iproute2
      jq
      openvpn
      procps
      wireguard-tools
    ]);
  cfg = config.services.piaManual;
  targetUser = cfg.runAfterLoginForUser;
  targetUserCfg =
    if targetUser == null then null
    else lib.attrByPath [ targetUser ] null config.users.users;
  targetUid =
    if targetUser == null then null else
    if targetUserCfg == null then
      throw "services.piaManual.runAfterLoginForUser references unknown user '${targetUser}'."
    else
      let uid = targetUserCfg.uid or null;
      in if uid == null then
        throw "services.piaManual.runAfterLoginForUser requires users.users.${targetUser}.uid to be set."
      else
        uid;
  targetUidStr =
    if targetUid == null then ""
    else builtins.toString targetUid;
  scriptVars = ''
    env_file='${cfg.envFile}'
    work_dir='${cfg.workDir}'
    script_dir='${cfg.scriptDirectory}'
    script_name='${cfg.scriptName}'
    script_path="$script_dir/$script_name"
  '';
  prepareScript = ''
    if [ ! -r "$env_file" ]; then
      echo "pia-manual: env file not found at $env_file" >&2
      exit 1
    fi

    mkdir -p "$work_dir"

    if [ ! -x "$script_path" ]; then
      tmp_dir="$(mktemp -d "$work_dir/download.XXXXXX")"
      cleanup() {
        rm -rf "$tmp_dir"
      }
      trap cleanup EXIT

      archive="$tmp_dir/manual-connections.tar.gz"
      curl -fsSL '${repoUrl}' -o "$archive"
      tar -xzf "$archive" -C "$tmp_dir"

      extracted="$(find "$tmp_dir" -maxdepth 1 -mindepth 1 -type d -name 'manual-connections-*' | head -n1)"
      if [ -z "$extracted" ]; then
        echo "pia-manual: failed to unpack manual-connections archive" >&2
        exit 1
      fi

      rm -rf "$script_dir"
      mkdir -p "$script_dir"
      cp -a "$extracted/." "$script_dir/"
      chmod +x "$script_path"

      trap - EXIT
      rm -rf "$tmp_dir"
    fi

    fix_shebang() {
      local target="$1"
      if [ -f "$target" ] && head -n1 "$target" | grep -q '^#! */bin/bash'; then
        sed -i '1s|^#! */bin/bash|#!/usr/bin/env bash|' "$target"
      fi
    }

    for script in run_setup.sh get_dip.sh get_token.sh get_region.sh; do
      fix_shebang "$script_dir/$script"
    done
  '';
  runScript = ''
    ${lib.optionalString cfg.disconnectBeforeRun ''
    if ${pkgs.wireguard-tools}/bin/wg show pia >/dev/null 2>&1; then
      echo "pia-manual: found existing WireGuard interface 'pia'; bringing it down."
      ${pkgs.wireguard-tools}/bin/wg-quick down pia >/dev/null 2>&1 || true
    fi
    ''}

    set -a
    . "$env_file"
    set +a

    ${lib.optionalString (cfg.portForwarding != null) ''
    if [ -z ''${PIA_PF:-} ]; then
      export PIA_PF="${if cfg.portForwarding then "true" else "false"}"
    fi
    ''}

    cd "$script_dir"
    ${pkgs.bash}/bin/bash "$script_path"
  '';
in
{
  options.services.piaManual = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to automatically run the PIA manual-connections setup during
        system activation (every nixos-rebuild switch). If enabled the module
        sources `envFile`, makes sure run_setup.sh exists, and executes it.
      '';
    };

    envFile = lib.mkOption {
      type = lib.types.str;
      default = defaultEnvFile;
      description = ''
        Absolute path to the environment file that defines PIA_USER, PIA_PASS,
        DIP_TOKEN, AUTOCONNECT, VPN_PROTOCOL, DISABLE_IPV6, PIA_DNS and any
        other variables consumed by run_setup.sh.
      '';
    };

    workDir = lib.mkOption {
      type = lib.types.str;
      default = defaultWorkDir;
      description = ''
        Directory that stores the downloaded manual-connections archive. It is
        created on demand and only populated when the scripts are missing.
      '';
    };

    scriptDirectory = lib.mkOption {
      type = lib.types.str;
      default = defaultScriptDirectory;
      description = ''
        Directory containing the manual-connections scripts. If run_setup.sh is
        missing the module fetches the GitHub archive and repopulates this path.
      '';
    };

    scriptName = lib.mkOption {
      type = lib.types.str;
      default = defaultScriptName;
      description = "Script invoked inside `scriptDirectory` (defaults to run_setup.sh).";
    };

    portForwarding = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = false;
      description = ''
        Desired answer to the port-forwarding prompt. `true` exports PIA_PF=true,
        `false` exports PIA_PF=false, and `null` leaves the upstream script to
        prompt (useful when you want to decide interactively).
      '';
    };

    disconnectBeforeRun = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When true, bring down an existing WireGuard interface named `pia`
        before running run_setup.sh. This keeps the upstream scripts from
        hanging when a previous session is still active.
      '';
    };

    runAfterLoginForUser = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        When set to a username, run_setup.sh is skipped during system
        activation and executed only after the specified user has logged in
        (detected via /run/user/<uid>). This keeps interactive prompts away
        from the early boot stage.
      '';
      example = "luix";
    };
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.pia-manual = lib.stringAfter [ "etc" ] ''
      set -euo pipefail
      export PATH=${runtimePath}

      ${scriptVars}

      ${prepareScript}
      ${lib.optionalString (cfg.runAfterLoginForUser == null) runScript}
    '';

    systemd.services.pia-manual-after-login = lib.mkIf (cfg.runAfterLoginForUser != null) {
      description = "PIA manual-connections setup after user login";
      wantedBy = [ "user@${targetUidStr}.service" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" "user@${targetUidStr}.service" ];
      partOf = [ "user@${targetUidStr}.service" ];
      path = with pkgs; [
        bash
        coreutils
      ];
      script = ''
        set -euo pipefail
        export PATH=${runtimePath}

        ${scriptVars}

        user='${cfg.runAfterLoginForUser}'
        uid='${targetUidStr}'
        if ! ${pkgs.coreutils}/bin/id "$user" >/dev/null 2>&1; then
          echo "pia-manual: user $user not found" >&2
          exit 1
        fi
        if [ ! -d "/run/user/$uid" ]; then
          echo "pia-manual: runtime directory for $user not present; skipping." >&2
          exit 0
        fi

        ${prepareScript}
        ${runScript}
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}
