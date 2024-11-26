-- nix lsp client named nil
return {
  -- tell mason to install nil
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed or {}, { "nil" })
    end,
  },
  -- add nil to nvim-lspconfig

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = { nil_ls = {} },
      setup = {
        ["nil_ls"] = function()
          LazyVim.lsp.on_attach(function(client, _)
            if client.name == "nil_ls" then
              client.settings = {
                ["nil"] = {
                  testSetting = 42,
                  formatting = {
                    command = { "nixpkgs-fmt" },
                  },
                },
              }
            end
          end)
        end,
      },
    },
  },
  -- added nix to telescope languages
}
