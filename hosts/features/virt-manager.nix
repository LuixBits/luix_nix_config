{ pkgs, ... }:
{
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      swtpm.enable = true;
      vhostUserPackages = [ pkgs.virtiofsd ];
    };
  };

  users.users.luiz.extraGroups = [
    "libvirtd"
    "kvm"
  ];

  environment.systemPackages = with pkgs; [
    dnsmasq
  ];

  networking.firewall.trustedInterfaces = [ "virbr0" ];

  systemd.services.libvirt-default-network = {
    description = "Start the libvirt default NAT network";
    wantedBy = [ "multi-user.target" ];
    requires = [ "libvirtd.service" ];
    after = [
      "libvirtd-config.service"
      "libvirtd.service"
    ];
    path = with pkgs; [
      gnugrep
      libvirt
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      virsh -c qemu:///system net-info default >/dev/null
      virsh -c qemu:///system net-autostart default

      if ! virsh -c qemu:///system net-info default | grep -q '^Active:[[:space:]]*yes'; then
        virsh -c qemu:///system net-start default
      fi
    '';
  };
}
