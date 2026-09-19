{ ... }:
{
  # Shared-store capture VM (nixos-rebuild build-vm). The bootable capture
  # host lives in capture.nix; this variant is for quick desktop footage.
  virtualisation.vmVariant = {
    imports = [ ./capture-extras.nix ];
    virtualisation = {
      memorySize = 8192;
      cores = 8;
      diskSize = 40 * 1024;
      forwardPorts = [
        {
          from = "host";
          host.port = 2222;
          guest.port = 22;
        }
      ];
      # egl-headless keeps GL for Noctalia without a host window; a window
      # would let GTK resize the guest away from the panel resolution.
      # Watch live via VNC on 127.0.0.1:5907; capture happens inside the
      # guest at native resolution.
      qemu.options = [
        "-vga none"
        "-device virtio-vga-gl,xres=2880,yres=1800"
        "-display egl-headless"
        "-vnc 127.0.0.1:7"
      ];
    };
  };
}
