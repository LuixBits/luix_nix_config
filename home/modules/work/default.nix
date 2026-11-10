# User tools and preferences required by the work environment.
{ config, lib, pkgs, ... }:
let
  webshopRuntime = "${config.home.homeDirectory}/.codex/mcp-runtimes/webshop";
  webshopRevision = "46414ab4e54b07c4b98856ae36668e6922751ef7";
  webshopMcp = {
    command = "${webshopRuntime}/${webshopRevision}/src/html/bin/webshop";
    args = [ "mcp:webshop" "--config" "${webshopRuntime}/manifest.json" ];
    enabled = true;
    startup_timeout_sec = 20;
    tool_timeout_sec = 210;
    enabled_tools = [
      "webshop_architecture_overview"
      "webshop_architecture_interface_inspect"
      "webshop_architecture_contract_inspect"
      "webshop_crm_metadata_inspect_dev"
      "webshop_crm_order_inspect_dev"
      "webshop_crm_metadata_inspect_test"
      "webshop_crm_order_inspect_test"
      "webshop_price_cache_inspect_local"
      "webshop_runtime_inspect_dev"
      "webshop_runtime_inspect_test"
      "webshop_customer_context_inspect_dev"
      "webshop_customer_context_inspect_test"
      "webshop_architecture_search"
      "webshop_architecture_flow_inspect"
    ];
    env_vars = [ "AZURE_CONFIG_DIR" "KUBECONFIG" "SSH_AUTH_SOCK" ];
    env.PATH = lib.concatStringsSep ":" [
      "${webshopRuntime}/node/bin"
      "${config.home.homeDirectory}/.nix-profile/bin"
      "/etc/profiles/per-user/${config.home.username}/bin"
      "/run/current-system/sw/bin"
      "/usr/bin"
      "/bin"
    ];
  };
  webshopMcpToml = (pkgs.formats.toml { }).generate "webshop-mcp.toml" {
    mcp_servers.webshop = webshopMcp;
  };
  writeWebshopMcp = pkgs.writeShellScript "write-codex-webshop-mcp" ''
    set -eu
    config_file="$1"
    tmp_file="$config_file.tmp.$$"
    trap '${pkgs.coreutils}/bin/rm -f "$tmp_file"' EXIT
    ${pkgs.gawk}/bin/awk '
      /^[[:space:]]*\[mcp_servers[.]webshop([.][^]]*)?\][[:space:]]*$/ { skip = 1; next }
      skip && /^[[:space:]]*\[/ { skip = 0 }
      !skip { print }
    ' "$config_file" > "$tmp_file"
    ${pkgs.coreutils}/bin/printf '\n' >> "$tmp_file"
    ${pkgs.coreutils}/bin/cat ${webshopMcpToml} >> "$tmp_file"
    ${pkgs.coreutils}/bin/chmod 0600 "$tmp_file"
    ${pkgs.coreutils}/bin/mv "$tmp_file" "$config_file"
    trap - EXIT
  '';
in
{
  imports = [
    ../teams
  ];

  # Keep the mutable Codex config and its other integrations intact on rebuild.
  # The private runtime and captured manifest are installed separately.
  home.activation.ensureWebshopMcp = lib.hm.dag.entryAfter [
    "ensureCodexConfig"
    "ensureGraphifyAgentIntegrations"
  ] ''
    run ${writeWebshopMcp} "${config.home.homeDirectory}/.codex/config.toml"
  '';

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user = {
        name = "Luiz Perren";
        email = "luiz.perren@siga.swiss";
      };
      init.defaultBranch = "main";
      pull.rebase = false;
      color.ui = "auto";
      core.editor = "vim";
      credential.helper = "cache";
    };
  };

  programs.ssh.settings."ssh.dev.azure.com" = {
    User = "git";
    IdentityFile = "${config.home.homeDirectory}/.ssh/azure_devops";
    IdentitiesOnly = true;
  };

  programs.java = {
    enable = true;
    package = pkgs.jdk;
  };

  programs.fish.shellAliases = {
    pia = "pia-setup --connect";
    piaoff = "pia-setup --disconnect";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/siga/roiguard/bin"
    "${config.home.homeDirectory}/siga/webshop/src/html/bin"
    "${config.home.homeDirectory}/siga/bincommands/bin"
  ];

  # Azure CLI/Python requests must use the system bundle, which includes the
  # SIGA Gateway CA alongside the normal public certificate authorities.
  home.sessionVariables.REQUESTS_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt";

  # The paired system work module imports the company CA from a local file.
  # Plain rebuild-helper invocations must allow that read automatically.
  programs.buildandpush.impure = true;

  xdg.configFile."fish/completions/siga.fish".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/siga/bincommands/completions/siga.fish";

  home.packages = with pkgs; [
    azure-cli
    brave
    cloudflare-warp
    deckmaster
    filezilla
    go
    htop
    jq
    kubectl
    kubelogin
    mysql84
    openssl
    php83Packages.composer
    spotify
    vivaldi
    vim
  ];
}
