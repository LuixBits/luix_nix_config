{
  picker = "telescope";

  annotations = {
    sign_style = "auto";
  };

  detail = {
    split = "tab";
  };

  dashboard = {
    split = "sidebar";
    live = {
      enable = false;
      interval = 60000;
    };
  };

  scratch = {
    split = "float";
    sync_annotations = true;
    live = {
      enable = false;
      interval = 60000;
    };
  };

  layout = {
    sidebar = {
      width = 50;
      side = "right";
    };
  };

  buffer_keymaps = {
    enable = true;
    prefix = "<localleader>s";
  };

  path_resolution = {
    trust_unmapped_absolute = false;
  };
}
