{
  config,
  pkgs,
  ...
}: let
  notesDir = "${config.home.homeDirectory}/notes";
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

      local function norg_image_template(context)
        local current_file = vim.api.nvim_buf_get_name(0)
        if current_file == "" then
          return ".image " .. context.file_path
        end

        local current_dir = vim.fn.fnamemodify(current_file, ":p:h")
        local absolute_path = vim.fs.normalize(current_dir .. "/" .. context.file_path)

        if absolute_path == notes_dir or vim.startswith(absolute_path, notes_dir .. "/") then
          return ".image $notes/" .. absolute_path:sub(#notes_dir + 2)
        end

        return ".image " .. context.file_path
      end

      local function resolve_neorg_image_path(_, src)
        if type(src) ~= "string" then
          return nil
        end

        if vim.startswith(src, "~/") then
          return vim.fn.expand(src)
        end

        if src == "$notes" then
          return notes_dir
        end

        if vim.startswith(src, "$notes/") then
          return vim.fs.normalize(notes_dir .. "/" .. src:sub(8))
        end

        if vim.startswith(src, "$") then
          local ok, neorg = pcall(require, "neorg.core")
          if ok then
            local ok_utils, dirman_utils = pcall(neorg.modules.get_module, "core.dirman.utils")
            if ok_utils and dirman_utils then
              local expanded = dirman_utils.expand_path(src, true)
              if expanded then
                return expanded
              end
            end
          end
        end

        return nil
      end

      require("snacks").setup({
        image = {
          enabled = true,
          resolve = resolve_neorg_image_path,
          doc = {
            enabled = true,
            inline = true,
            float = true,
            max_width = 90,
            max_height = 24,
            conceal = false,
          },
          img_dirs = { "assets", "img", "images", "media", "attachments" },
        },
      })

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

      local function attach_neorg_images(buf)
        local ok, image_doc = pcall(require, "snacks.image.doc")
        if ok then
          image_doc.attach(buf)
        end
      end

      vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
        pattern = "norg",
        callback = function(args)
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(args.buf) then
              attach_neorg_images(args.buf)
            end
          end)
        end,
      })

      if vim.bo.filetype == "norg" then
        vim.schedule(function()
          attach_neorg_images(vim.api.nvim_get_current_buf())
        end)
      end

      require("img-clip").setup({
        default = {
          dir_path = "assets",
          extension = "png",
          use_absolute_path = false,
          relative_to_current_file = true,
          relative_template_path = true,
          prompt_for_file_name = false,
          show_dir_path_in_prompt = false,
          copy_images = true,
          download_images = true,
          url_encode_path = false,
          template = norg_image_template,
          insert_mode_after_paste = false,
          insert_template_after_cursor = true,
        },
        filetypes = {
          norg = {
            template = norg_image_template,
          },
        },
      })
    '';
  };
}
