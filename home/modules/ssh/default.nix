{ ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    # Each host name appears in the Herdr Utils SSH picker.
    # Add servers here; HostName is the address and User is the remote login.
    settings = {
      "MiniLab" = {
        HostName = "192.168.18.13";
        User = "luix";
      };
    };
  };
}
