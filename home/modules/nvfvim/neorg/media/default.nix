{
  config,
  pkgs,
  ...
}: let
  notesDir = "${config.home.homeDirectory}/notes";
  imageMaxWidth = 72;
  imageMaxHeight = 16;
in {
  home.packages = [
    pkgs.ghostscript
    pkgs.imagemagick
    pkgs.wl-clipboard
  ];

  programs.nvf.settings.vim = {
    startPlugins = [
      pkgs.vimPlugins.img-clip-nvim
      pkgs.vimPlugins.snacks-nvim
    ];

    luaConfigRC.neorg-media = ''
      local notes_dir = vim.fn.expand(${builtins.toJSON notesDir})

      vim.treesitter.query.set("norg", "images", [[
        (infirm_tag
          name: (tag_name) @tag
          (#eq? @tag "image")
          (tag_parameters (tag_param) @image.src)) @image

        (_
          (infirm_tag
            name: (tag_name) @tag
            (#eq? @tag "image")) @image
          .
          (paragraph (paragraph_segment) @image.src))
      ]])

      local function strip_quotes(value)
        return value:gsub("^['\"]", ""):gsub("['\"]$", "")
      end

      local function notes_relative_path(path)
        local absolute = vim.fs.normalize(path)
        if absolute == notes_dir then
          return "$notes"
        end
        if vim.startswith(absolute, notes_dir .. "/") then
          return "$notes/" .. absolute:sub(#notes_dir + 2)
        end
      end

      local function image_template(context)
        local path = context.file_path
        local current_file = vim.api.nvim_buf_get_name(0)

        if current_file ~= "" and not path:match("^/") and not vim.startswith(path, "$") then
          local current_dir = vim.fn.fnamemodify(current_file, ":p:h")
          path = vim.fs.normalize(current_dir .. "/" .. path)
        end

        return ".image " .. (notes_relative_path(path) or context.file_path)
      end

      local function resolve_image(_, src)
        if type(src) ~= "string" then
          return nil
        end

        src = strip_quotes(vim.trim(src))

        if vim.startswith(src, "~/") then
          return vim.fn.expand(src)
        end
        if src == "$notes" then
          return notes_dir
        end
        if vim.startswith(src, "$notes/") then
          return vim.fs.normalize(notes_dir .. "/" .. src:sub(8))
        end
      end

      require("snacks").setup({
        image = {
          enabled = true,
          resolve = resolve_image,
          doc = {
            enabled = true,
            inline = true,
            float = true,
            max_width = ${toString imageMaxWidth},
            max_height = ${toString imageMaxHeight},
            conceal = function(lang, _)
              return lang == "norg"
            end,
          },
          img_dirs = { "assets", "img", "images", "media", "attachments" },
        },
      })

      require("img-clip").setup({
        default = {
          dir_path = "assets",
          extension = "png",
          relative_to_current_file = true,
          relative_template_path = true,
          prompt_for_file_name = false,
          show_dir_path_in_prompt = false,
          copy_images = true,
          download_images = true,
          url_encode_path = false,
          template = image_template,
          insert_mode_after_paste = false,
          insert_template_after_cursor = true,
        },
      })
    '';
  };
}
