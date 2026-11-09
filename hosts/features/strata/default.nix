{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.services.strata;
  models = pkgs.callPackage ./models.nix { strata = cfg.package; };
  profile =
    name:
    let
      model = models.${name};
    in
    pkgs.writeText "strata-${name}.json" (
      builtins.toJSON {
        exe = cfg.package.enginePath;
        backend = "hip";
        lib_dirs = [ "${cfg.package.engine}/libexec/strata" ];
        cwd = "/var/lib/strata/${name}";
        tokenizer = "${model}/pack/tokenizer";
        model_name = "qwen3.8-flash-next-${name}";
        log = "/var/lib/strata/${name}/engine.log";
        args = [
          "--pack"
          "${model}/pack"
          "--native"
          "${model}/model/${model.stem}-00001-of-00002.gguf"
          "--ple-gguf"
          "${model}/model/${model.stem}-00002-of-00002.gguf"
          "--expert-profile"
          "${cfg.package}/lib/strata/data/expert-profile.bin"
          "--expert-cache"
          "auto"
          "--resident-experts"
          "--ram-keep-gib"
          "8"
          "--prefill"
          "512"
          # Native IQ packs require the windowed engine even without an MTP drafter.
          "--spec"
          "2"
          "--suffix-draft"
          "0"
          "--lookup-max-t"
          "0"
          "--max-context"
          (toString cfg.contextSize)
          "--kv"
          "int8"
          "--vram-reserve-mib"
          (toString cfg.vramReserveMiB)
          "--memory-limit-mib"
          "51200"
          "--conversation-cache-mib"
          "512"
          "--pool-workers"
          (toString cfg.cpuWorkers)
          "--adapt-every"
          "0"
          "--pcie-frac"
          "0"
        ];
        drafting = "off";
        parallel = 1;
        lazy_load = true;
        idle_unload_s = cfg.idleUnloadSeconds;
        api_key = "none";
      }
    );
  rule =
    client: action:
    "iptables -w ${action} nixos-fw -i ${lib.escapeShellArg cfg.lanInterface} -s ${lib.escapeShellArg client} -p tcp --dport ${toString cfg.port} -j nixos-fw-accept";
in
{
  options.services.strata = {
    enable = mkEnableOption "Strata with pinned normal and abliterated Qwen3.8 Flash-Next models";
    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./package.nix { };
      description = "Strata package including the RX 7900 HIP engine.";
    };
    models = mkOption {
      type = types.listOf (
        types.enum [
          "normal"
          "abliterated"
        ]
      );
      default = [
        "normal"
        "abliterated"
      ];
      description = "Variants to install; their common lookup shard is stored once.";
    };
    defaultModel = mkOption {
      type = types.enum [
        "normal"
        "abliterated"
      ];
      default = "normal";
      description = "Variant started at boot. Starting another variant stops this one.";
    };
    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "IPv4 listen address. Use 0.0.0.0 with allowedClients for LAN access.";
    };
    port = mkOption {
      type = types.port;
      default = 8080;
    };
    lanInterface = mkOption {
      type = types.str;
      default = "";
      description = "Interface on which allowedClients may reach the API.";
    };
    allowedClients = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "192.168.18.13/32" ];
      description = "Trusted IPv4 clients/CIDRs allowed through the firewall. The API has no key.";
    };
    gpuDevice = mkOption {
      type = types.str;
      default = "0";
      description = "ROCR_VISIBLE_DEVICES value; prefer the discrete GPU UUID on dual-GPU PCs.";
    };
    contextSize = mkOption {
      type = types.ints.between 4096 131072;
      default = 32768;
    };
    vramReserveMiB = mkOption {
      type = types.ints.positive;
      default = 3072;
    };
    cpuWorkers = mkOption {
      type = types.ints.unsigned;
      default = 0;
    };
    idleUnloadSeconds = mkOption {
      type = types.ints.unsigned;
      default = 900;
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
        message = "services.strata currently packages only the x86_64 RX 7900 HIP engine.";
      }
      {
        assertion = lib.elem cfg.defaultModel cfg.models;
        message = "services.strata.defaultModel must be included in services.strata.models.";
      }
      {
        assertion =
          cfg.allowedClients == [ ] || (cfg.lanInterface != "" && !config.networking.nftables.enable);
        message = "Strata LAN rules require lanInterface and the NixOS iptables firewall backend.";
      }
    ];

    environment.systemPackages = [
      cfg.package
      (pkgs.callPackage ./comparison.nix { })
    ];
    environment.etc = lib.listToAttrs (
      map (name: {
        name = "strata/${name}.json";
        value.source = profile name;
      }) cfg.models
    );

    networking.firewall.extraCommands = lib.concatMapStringsSep "\n" (
      client: rule client "-A"
    ) cfg.allowedClients;
    networking.firewall.extraStopCommands = lib.concatMapStringsSep "\n" (
      client: "${rule client "-D"} 2>/dev/null || true"
    ) cfg.allowedClients;

    systemd.services = lib.listToAttrs (
      map (
        name:
        let
          others = map (n: "strata-${n}.service") (lib.filter (n: n != name) cfg.models);
        in
        {
          name = "strata-${name}";
          value = {
            description = "Strata Qwen3.8 Flash-Next (${name})";
            wantedBy = lib.optional (name == cfg.defaultModel) "multi-user.target";
            after = [
              "network.target"
              "ollama.service"
            ]
            ++ lib.filter (other: other < "strata-${name}.service") others;
            conflicts = [ "ollama.service" ] ++ others;
            environment = {
              ROCR_VISIBLE_DEVICES = cfg.gpuDevice;
              PYTHONDONTWRITEBYTECODE = "1";
            };
            serviceConfig = {
              ExecStart = lib.escapeShellArgs [
                "${cfg.package}/bin/strata-server"
                "--engine"
                "strata"
                "--config"
                (profile name)
                "--host"
                cfg.host
                "--port"
                (toString cfg.port)
                "--offline"
                "--max-queue"
                "4"
                "--queue-timeout"
                "600"
              ];
              DynamicUser = true;
              SupplementaryGroups = [
                "render"
                "video"
              ];
              StateDirectory = "strata/${name}";
              WorkingDirectory = "/var/lib/strata/${name}";
              Restart = "on-failure";
              RestartSec = 10;
              TimeoutStopSec = 60;
              LimitMEMLOCK = "infinity";
              MemoryMax = "50G";
              NoNewPrivileges = true;
              ProtectSystem = "strict";
              ProtectHome = true;
              PrivateTmp = true;
              UMask = "0077";
              IPAddressDeny = "any";
              IPAddressAllow = [ "localhost" ] ++ cfg.allowedClients;
            };
          };
        }
      ) cfg.models
    );
  };
}
