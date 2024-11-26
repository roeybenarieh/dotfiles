return {
  -- https://github.com/nvim-treesitter/nvim-treesitter?tab=readme-ov-file#supported-languages
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = {
      "vim",
      "markdown_inline",
      "lua",
      "python",
      "bash",
      "go",
      "markdown",
      "rust",
      "cpp",
      "c_sharp",
      "javascript",
      "typescript",
      "query", -- for tree-sitter queries
      "sql",
      "promql",
      "helm",
      "regex",
      "html",
      "css",
      "json",
      "json5",
      "yaml",
      "ini",
      "toml",
      "requirements", -- python pip requirements
      "nix",
      "just",
      "dockerfile",
      "git_config", -- .git/config file
      "git_rebase", -- git interactive rebase file
      "gitattributes", -- .gitattributes file, resource: https://git-scm.com/book/en/v2/Customizing-Git-Git-Attributes
      "gitcommit", -- git commit message using the "conventional commits" specifications
      "gitignore", -- .gitignore file
      "comment", -- comments in any language
    },
  },
}
