-- ============================================
--  Réglages de base
-- ============================================
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.termguicolors = true
vim.opt.clipboard = "unnamedplus"
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250

-- ============================================
--  Installation automatique de lazy.nvim
-- ============================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- ============================================
--  Plugins
-- ============================================
require("lazy").setup({

  -- Thème
  { "catppuccin/nvim", name = "catppuccin", priority = 1000,
    config = function() vim.cmd.colorscheme("catppuccin-mocha") end },

  -- Recherche de fichiers et de texte (l'équivalent du Ctrl-Shift-F de Rider)
  { "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Fichiers" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>",  desc = "Rechercher" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>",    desc = "Buffers" },
    },
  },

  -- Explorateur de fichiers latéral
  { "nvim-tree/nvim-tree.lua",
    keys = { { "<leader>e", "<cmd>NvimTreeToggle<cr>", desc = "Explorateur" } },
    opts = {},
  },

  -- Coloration syntaxique fine
  { "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    opts = { ensure_installed = { "c_sharp", "lua", "sql", "json", "yaml" },
             highlight = { enable = true } },
    config = function(_, opts) require("nvim-treesitter.configs").setup(opts) end },

  -- Autocomplétion
  { "hrsh7th/nvim-cmp",
    dependencies = { "hrsh7th/cmp-nvim-lsp", "L3MON4D3/LuaSnip", "saadparwaiz1/cmp_luasnip" },
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        snippet = { expand = function(a) require("luasnip").lsp_expand(a.body) end },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"]      = cmp.mapping.confirm({ select = true }),
          ["<Tab>"]     = cmp.mapping.select_next_item(),
          ["<S-Tab>"]   = cmp.mapping.select_prev_item(),
        }),
        sources = { { name = "nvim_lsp" }, { name = "luasnip" } },
      })
    end },

  -- === Le cœur du dispositif C# ===
  { "seblyng/roslyn.nvim",
    ft = "cs",
    config = function()
      vim.lsp.config("roslyn", {
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
      })
      require("roslyn").setup()
    end },

  -- Client base de données (voir étape 8)
  { "tpope/vim-dadbod" },
  { "kristijanhusak/vim-dadbod-ui",
    dependencies = { "tpope/vim-dadbod", "kristijanhusak/vim-dadbod-completion" },
    cmd = { "DBUI", "DBUIToggle" },
    init = function() vim.g.db_ui_use_nerd_fonts = 0 end },
})

-- ============================================
--  Raccourcis LSP (actifs dès qu'un serveur s'attache)
-- ============================================
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local map = function(k, fn, desc)
      vim.keymap.set("n", k, fn, { buffer = ev.buf, desc = desc })
    end
    map("gd", vim.lsp.buf.definition,      "Aller à la définition")
    map("gr", vim.lsp.buf.references,      "Références")
    map("gi", vim.lsp.buf.implementation,  "Implémentations")
    map("K",  vim.lsp.buf.hover,           "Documentation")
    map("<leader>rn", vim.lsp.buf.rename,  "Renommer")
    map("<leader>ca", vim.lsp.buf.code_action, "Action de code")
    map("<leader>fm", function() vim.lsp.buf.format() end, "Formater")
    map("[d", function() vim.diagnostic.jump({ count = -1 }) end, "Diagnostic précédent")
    map("]d", function() vim.diagnostic.jump({ count = 1 })  end, "Diagnostic suivant")
  end,
})
