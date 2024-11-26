-- nix formatter named nixpkgs_fmt
return {
  -- tell mason to install nixpkgs_fmt
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed or {}, { "nixpkgs-fmt" })
    end,
  },
  -- add alejandra to null-ls
  {
    "nvimtools/none-ls.nvim",
    opts = function(_, opts)
      local nls = require("null-ls")
      opts.sources = opts.sources or {}
      table.insert(opts.sources, nls.builtins.formatting.nixpkgs_fmt)
    end,
  },
  -- tell conform to use alejandra
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        ["nix"] = { "nixpkgs-fmt " },
      },
    },
  },
}
