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

  -- Recherche floue, explorateur de fichiers et icônes
  { "nvim-mini/mini.nvim",
    version = false,
    keys = {
      { "<leader>ff", function() MiniPick.builtin.files() end,     desc = "Fichiers" },
      { "<leader>fg", function() MiniPick.builtin.grep_live() end, desc = "Rechercher" },
      { "<leader>fb", function() MiniPick.builtin.buffers() end,   desc = "Buffers" },
      { "<leader>e",  function() MiniFiles.open() end,             desc = "Explorateur" },
    },
    config = function()
      require("mini.icons").setup()
      require("mini.pick").setup()
      require("mini.files").setup()
    end },

  -- Coloration syntaxique fine
  { "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").install({
        "c_sharp", "razor", "xml", "html", "css", "javascript", "typescript",
        "json", "yaml", "toml", "ini", "sql",
        "markdown", "markdown_inline", "bash", "python", "lua",
        "vim", "vimdoc", "query", "regex", "diff", "dockerfile",
        "gitcommit", "gitignore", "git_config", "git_rebase",
      })

      local LIGNES_MAX_AVANT_RALENTISSEMENT_DU_PARSING = 20000

      local function activer_coloration_si_parser_disponible(evenement)
        if vim.api.nvim_buf_line_count(evenement.buf) > LIGNES_MAX_AVANT_RALENTISSEMENT_DU_PARSING then
          return
        end
        local langage = vim.treesitter.language.get_lang(evenement.match)
        local parser_charge, disponible = pcall(vim.treesitter.language.add, langage)
        if parser_charge and disponible then
          pcall(vim.treesitter.start, evenement.buf, langage)
        end
      end

      vim.api.nvim_create_autocmd("FileType", { callback = activer_coloration_si_parser_disponible })
    end },

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

  -- === Débogage ===
  { "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "theHamsta/nvim-dap-virtual-text",
    },
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      dapui.setup()
      require("nvim-dap-virtual-text").setup()

      dap.listeners.before.attach.dapui_config           = function() dapui.open() end
      dap.listeners.before.launch.dapui_config           = function() dapui.open() end
      dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
      dap.listeners.before.event_exited.dapui_config     = function() dapui.close() end

      local function chemin_du_debogueur()
        local installe_sur_le_systeme = vim.fn.exepath("netcoredbg")
        if installe_sur_le_systeme ~= "" then return installe_sur_le_systeme end
        return vim.fn.stdpath("data") .. "/mason/bin/netcoredbg"
      end

      dap.adapters.coreclr = {
        type = "executable",
        command = chemin_du_debogueur(),
        args = { "--interpreter=vscode" },
      }

      local function la_plus_recemment_compilee(a, b)
        return vim.fn.getftime(a) > vim.fn.getftime(b)
      end

      local function dll_du_projet_courant()
        local racine = vim.fn.getcwd()
        local nom = vim.fn.fnamemodify(racine, ":t")
        local compilations = vim.fn.glob(racine .. "/bin/Debug/*/" .. nom .. ".dll", false, true)
        table.sort(compilations, la_plus_recemment_compilee)
        if #compilations > 0 then return compilations[1] end
        return vim.fn.input("Chemin de la DLL : ", racine .. "/bin/Debug/", "file")
      end

      local function compiler_puis_localiser_la_dll()
        local sortie = vim.fn.system({ "dotnet", "build", vim.fn.getcwd() })
        if vim.v.shell_error ~= 0 then
          error("Échec de la compilation, débogage annulé :\n" .. sortie)
        end
        return dll_du_projet_courant()
      end

      dap.configurations.cs = {
        {
          type = "coreclr",
          name = "Lancer (build + debug)",
          request = "launch",
          program = compiler_puis_localiser_la_dll,
          env = { ASPNETCORE_ENVIRONMENT = "Development" },
        },
        {
          type = "coreclr",
          name = "Attacher à un processus",
          request = "attach",
          processId = require("dap.utils").pick_process,
        },
      }
    end,
    keys = {
      -- Touches calquées sur Rider
      { "<F5>",  function() require("dap").continue() end,          desc = "Continuer / démarrer" },
      { "<F8>",  function() require("dap").step_over() end,         desc = "Pas au-dessus" },
      { "<F7>",  function() require("dap").step_into() end,         desc = "Pas dans" },
      { "<S-F8>",function() require("dap").step_out() end,          desc = "Pas hors" },
      { "<leader>b", function() require("dap").toggle_breakpoint() end, desc = "Breakpoint" },
      { "<leader>B", function()
          require("dap").set_breakpoint(vim.fn.input("Condition : "))
        end, desc = "Breakpoint conditionnel" },
      { "<leader>dr", function() require("dap").repl.open() end,    desc = "Console REPL" },
      { "<leader>du", function() require("dapui").toggle() end,     desc = "Interface debug" },
      { "<leader>dt", function() require("dap").terminate() end,    desc = "Arrêter" },
      { "<leader>dk", function() require("dapui").eval() end,       desc = "Évaluer sous le curseur" },
    },
  },

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
