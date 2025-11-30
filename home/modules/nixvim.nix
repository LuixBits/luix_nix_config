{ pkgs, inputs, ... }:
{
  imports = [ 
    inputs.nixvim.homeManagerModules.nixvim 
  ];

  programs.nixvim = { 
    enable = true; 
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;

    globals.mapleader = " ";

    opts = {
      #general settings
      clipboard = "unnamedplus";
      mouse = "a";
      splitbelow = true;
      splitright = true;
      timeoutlen = 500;
      termguicolors = true;
      completeopt = "menuone,noselect";
      updatetime = 300;

      #tab settings
      tabstop = 2;
      shiftwidth = 2;
      softtabstop = 2;
      expandtab = true;
      shiftround = true;
      autoindent = true;
      smartindent = true;

      #linenumbers
      number = true;
      relativenumber = true;
      wrap = false;
      cursorline = true;
      signcolumn = "yes";
      scrolloff = 8;
      sidescrolloff = 5;

      #search
      ignorecase = true;
      smartcase = true;
      incsearch = true;
      hlsearch = true;

      #swap
      swapfile = false;
      backup = false;
      writebackup = false;
      undofile = true;

      # text stuff
      list = true;
      listchars = {
        tab = "→ ";
        trail = "°";
        extends = "›";
        precedes = "‹";
      };

      #fold your laundry
      foldmethod = "indent";
      foldlevel = 99;
      foldenable = false;

    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>w";
        action = ":w<CR>";
        options.silent = false;
      }
      {
        mode = "n";
        key = "<leader>q";
        action = ":q<CR>";
        options.silent = false;
      }
    ];

    plugins = {
      lsp = {
        enable = true;
        servers = {
          vue_ls.enable   = true;
          ts_ls.enable   = true;
          cssls.enable   = true;
          jsonls.enable  = true;
          lua_ls.enable  = true;
          nixd.enable    = true;
        };
      };
      alpha = {
        enable = true;
        layout = [
          { type = "padding"; val = 4; }
          {
            type = "text";
            opts = { position = "center"; hl = "Type"; };
            val = [
              "  LLLLLLLLLLL                                 iiii                      BBBBBBBBBBBBBBBBB     iiii          tttt                           "
              "  L:::::::::L                                i::::i                     B::::::::::::::::B   i::::i      ttt:::t                           "
              "  L:::::::::L                                 iiii                      B::::::BBBBBB:::::B   iiii       t:::::t                           "
              "  LL:::::::LL                                                           BB:::::B     B:::::B             t:::::t                           "
              "    L:::::L               uuuuuu    uuuuuu  iiiiiii xxxxxxx      xxxxxxx  B::::B     B:::::Biiiiiiittttttt:::::ttttttt        ssssssssss   "
              "    L:::::L               u::::u    u::::u  i:::::i  x:::::x    x:::::x   B::::B     B:::::Bi:::::it:::::::::::::::::t      ss::::::::::s  "
              "    L:::::L               u::::u    u::::u   i::::i   x:::::x  x:::::x    B::::BBBBBB:::::B  i::::it:::::::::::::::::t    ss:::::::::::::s "
              "    L:::::L               u::::u    u::::u   i::::i    x:::::xx:::::x     B:::::::::::::BB   i::::itttttt:::::::tttttt    s::::::ssss:::::s"
              "    L:::::L               u::::u    u::::u   i::::i     x::::::::::x      B::::BBBBBB:::::B  i::::i      t:::::t           s:::::s  ssssss "
              "    L:::::L               u::::u    u::::u   i::::i      x::::::::x       B::::B     B:::::B i::::i      t:::::t             s::::::s      "
              "    L:::::L               u::::u    u::::u   i::::i      x::::::::x       B::::B     B:::::B i::::i      t:::::t                s::::::s   "
              "    L:::::L         LLLLLLu:::::uuuu:::::u   i::::i     x::::::::::x      B::::B     B:::::B i::::i      t:::::t    ttttttssssss   s:::::s "
              "  LL:::::::LLLLLLLLL:::::Lu:::::::::::::::uui::::::i   x:::::xx:::::x   BB:::::BBBBBB::::::Bi::::::i     t::::::tttt:::::ts:::::ssss::::::s"
              "  L::::::::::::::::::::::L u:::::::::::::::ui::::::i  x:::::x  x:::::x  B:::::::::::::::::B i::::::i     tt::::::::::::::ts::::::::::::::s "
              "  L::::::::::::::::::::::L  uu::::::::uu:::ui::::::i x:::::x    x:::::x B::::::::::::::::B  i::::::i       tt:::::::::::tt s:::::::::::ss  "
              "  LLLLLLLLLLLLLLLLLLLLLLLL    uuuuuuuu  uuuuiiiiiiiixxxxxxx      xxxxxxxBBBBBBBBBBBBBBBBB   iiiiiiii         ttttttttttt    sssssssssss    "
            ];
          }
          { type = "padding"; val = 2; }
          {
            type = "group";
            val = [
              { type = "button"; val = "  Find file"; on_press = "Telescope find_files"; }
              { type = "button"; val = "  Live grep"; on_press = "Telescope live_grep"; }
              { type = "button"; val = "  File tree"; on_press = "NvimTreeToggle"; }
              { type = "button"; val = "  Quit";      on_press = "qa"; }
            ];
            opts = { spacing = 1; };
          }
        ];
      };

    };

  };
}
