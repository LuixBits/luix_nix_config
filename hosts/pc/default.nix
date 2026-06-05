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

  # Use the newer USB4/Thunderbolt stack for the TS5 Plus dock.
  boot.kernelPackages = pkgs.linuxPackages_6_18;
  boot.initrd.availableKernelModules = [ "thunderbolt" ];
  boot.kernelParams = [
    # Same firmware reboot workaround used on the work host.
    "reboot=efi"
  ];

  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;

    # Expose Ollama to LAN clients such as the mini PC.
    host = "0.0.0.0";
    port = 11434;

    # Strong/fast coding default for the RX 7900 XTX 24GB VRAM class.
    loadModels = [ "qwen3-coder:30b" ];

    environmentVariables = {
      # Use only the 7900 XTX. Ollama also sees the Ryzen iGPU via ROCm,
      # but splitting inference onto it crashes rocBLAS for this model.
      ROCR_VISIBLE_DEVICES = "GPU-b029531ca159d189";

      # 256K context is the model maximum, not the fast 24GB-VRAM target.
      # 32K keeps the 30B coder model on the 7900 XTX with room for KV cache.
      OLLAMA_CONTEXT_LENGTH = "32768";

      # Keep the model warm briefly for agent workflows without pinning VRAM forever.
      OLLAMA_KEEP_ALIVE = "15m";
    };
  };

  networking.firewall.interfaces.enp10s0.allowedTCPPorts = [ 11434 ];

  environment.systemPackages = with pkgs; [
    dosfstools
    gparted
    pciutils
    rocmPackages.rocminfo
  ];
}
