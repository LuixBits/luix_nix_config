{ ... }:
{
  # Secondary NVMe (4TB, label LuixMass) for the desktop.
  fileSystems."/home/luix/Mass" = {
    device = "/dev/disk/by-uuid/270d2e79-7e41-4b83-8990-dad1412fcf45";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  systemd.tmpfiles.rules = [
    "d /home/luix/Mass 0755 luix users -"
  ];
}
