return {
  "lewis6991/gitsigns.nvim",
  event = "LazyFile",
  opts = {
    signs = {
      -- add = { text = "+" },
      -- change = { text = "~" },
      -- delete = { text = "-" },
      topdelete = { text = "-" },
      changedelete = { text = "-" },
      untracked = { text = "U" },
    },
    current_line_blame = true, -- Toggle with `:Gitsigns toggle_current_line_blame`
    on_attach = function(buffer)
      local gs = package.loaded.gitsigns

      local function map(mode, l, r, desc)
        vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
      end

      -- stylua: ignore start
      local wk = require("which-key")
      wk.add({
        { "<leader>ga", group = "git actions" },
        { "<leader>gas", ":Gitsigns stage_hunk<CR>", desc="Stage Hunk" ,mode = { "n", "v" }},
        { "<leader>gar", ":Gitsigns reset_hunk<CR>", desc="Reset Hunk" ,mode = { "n", "v" }},
        { "<leader>gaS", gs.stage_buffer, desc="Stage Buffer" },
        { "<leader>gau", gs.undo_stage_hunk, desc="Undo Stage Hunk" ,mode = { "n", "v" }},
        { "<leader>gaR", gs.reset_buffer, desc="Reset Buffer" },
        { "<leader>gap", gs.preview_hunk, desc="Preview Hunk" ,mode = { "n", "v" }},
        { "<leader>gab", function() gs.blame_line({ full = true }) end, desc="Blame Line" },
        { "<leader>gad", gs.diffthis, desc="Diff This" ,mode = { "n", "v" }},
        { "<leader>gaD", function() gs.diffthis("~") end, desc="Diff this ~" },
      })

      map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "GitSigns Select Hunk")
      map("n", "]h", gs.next_hunk, "Next Hunk")
      map("n", "[h", gs.prev_hunk, "Prev Hunk")
    end,
  },
}
