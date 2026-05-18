{ pkgs, ... }:
{
  imports = [
    ../common/base.nix
    ../features/hardware-amd.nix
    ../../audiofix.nix
    ../features/pc-mass-storage.nix
    ../features/media-tools.nix
    ../features/flatpak.nix
    ../features/gaming.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "pc";

  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;

    # Expose Ollama to LAN clients such as the mini PC.
    host = "0.0.0.0";
    port = 11434;

    # Strong/fast coding default for the RX 7900 XTX 24GB VRAM class.
    loadModels = [ "qwen3-coder:30b" ];

    environmentVariables = {
      # Keep the model warm briefly for agent workflows without pinning VRAM forever.
      OLLAMA_KEEP_ALIVE = "15m";
    };
  };

  networking.firewall.interfaces.enp10s0.allowedTCPPorts = [ 11434 ];

  environment.systemPackages = with pkgs; [
    pciutils
    rocmPackages.rocminfo
  ];
}
