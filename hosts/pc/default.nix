{ pkgs, ... }:
{
  imports = [
    ../common/base.nix
    ../features/hardware-amd.nix
    ../features/audio.nix
    ../features/pc-mass-storage.nix
    ../features/flatpak.nix
    ../features/gaming.nix
    ../../home/modules/simracing/nixos.nix
    ../features/corsair-cooling.nix
    ../features/spatial-input.nix
    ./hardware-configuration.nix
  ];

  hardware.spatial-input.enable = true;
  luix.simracing.enable = true;

  boot.initrd.availableKernelModules = [ "thunderbolt" ];
  boot.kernelParams = [
    # Work around firmware reboot behavior on this host.
    "reboot=efi"

    # This desktop's X670 USB-C controller failed to resume from runtime
    # suspend while attaching a dock. Keep dock peripherals active as well.
    "usbcore.autosuspend=-1"
  ];

  services.udev.extraRules = ''
    # Keep every AMD xHCI controller awake. This covers both the motherboard
    # rear USB-C port and the case USB-C port without relying on PCI addresses.
    ACTION=="add|bind|change", SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{class}=="0x0c0330", TEST=="power/control", ATTR{power/control}="on"
  '';

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

  system.stateVersion = "25.11";
}
