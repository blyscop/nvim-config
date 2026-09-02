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
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.undofile = true
vim.opt.fixendofline = false
vim.opt.scrolloff = 8
vim.opt.spell = true
vim.opt.spelllang = { "fr", "en" }
vim.cmd.colorscheme("vsdark")

local SERVEUR_ROSLYN_AVEC_CHANGE_SIGNATURE = "roslyn-language-server-cs"
if vim.fn.executable(SERVEUR_ROSLYN_AVEC_CHANGE_SIGNATURE) == 1 then
  vim.lsp.config("roslyn", { cmd = { SERVEUR_ROSLYN_AVEC_CHANGE_SIGNATURE, "--stdio" } })
end

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

  -- Recherche floue, explorateur de fichiers et icônes
  { "nvim-mini/mini.nvim",
    version = false,
    event = "VeryLazy",
    keys = {
      { "<leader>ff", function() MiniPick.builtin.files() end,     desc = "Fichiers" },
      { "<leader>fg", function() MiniPick.builtin.grep_live() end, desc = "Rechercher" },
      { "<leader>fb", function() MiniPick.builtin.buffers() end,   desc = "Buffers" },
      { "<leader>e",  function() MiniFiles.open() end,             desc = "Explorateur" },
      { "<leader>gh", function() MiniGit.show_at_cursor() end,      desc = "Historique sous le curseur" },
      { "<leader>gh", function() MiniGit.show_at_cursor() end,      desc = "Historique de la sélection", mode = "x" },
      { "<leader>gb", "<cmd>vertical Git blame -- %<cr>",           desc = "Blame du fichier" },
      { "<leader>gd", function() MiniDiff.toggle_overlay() end,     desc = "Superposition des différences" },
    },
    config = function()
      require("mini.icons").setup()
      require("mini.pick").setup()
      require("mini.files").setup()
      require("mini.jump2d").setup({ mappings = { start_jumping = "<leader>j" } })

      local objet_treesitter = require("mini.ai").gen_spec.treesitter
      require("mini.ai").setup({
        custom_textobjects = {
          f = objet_treesitter({ a = "@function.outer", i = "@function.inner" }),
          c = objet_treesitter({ a = "@class.outer", i = "@class.inner" }),
          o = objet_treesitter({
            a = { "@conditional.outer", "@loop.outer" },
            i = { "@conditional.inner", "@loop.inner" },
          }),
        },
      })
      require("mini.diff").setup()
      require("mini.git").setup()

      local function aligner_le_blame_sur_le_source(evenement)
        if evenement.data.git_subcommand ~= "blame" then return end
        vim.wo.wrap = false
        vim.fn.winrestview({ topline = vim.fn.line("w0", vim.fn.win_getid(vim.fn.winnr("#"))) })
        vim.wo.scrollbind = true
        vim.api.nvim_win_call(vim.fn.win_getid(vim.fn.winnr("#")), function()
          vim.wo.scrollbind = true
        end)
      end

      vim.api.nvim_create_autocmd("User", {
        pattern = "MiniGitCommandSplit",
        callback = aligner_le_blame_sur_le_source,
      })

      local clue = require("mini.clue")
      clue.setup({
        triggers = {
          { mode = "n", keys = "<Leader>" },
          { mode = "x", keys = "<Leader>" },
          { mode = "n", keys = "g" },
          { mode = "x", keys = "g" },
          { mode = "n", keys = "z" },
          { mode = "x", keys = "z" },
          { mode = "n", keys = "[" },
          { mode = "n", keys = "]" },
          { mode = "n", keys = "'" },
          { mode = "n", keys = "`" },
          { mode = "n", keys = '"' },
          { mode = "x", keys = '"' },
          { mode = "i", keys = "<C-r>" },
          { mode = "n", keys = "<C-w>" },
        },
        clues = {
          { mode = "n", keys = "<Leader>d", desc = "+Débogage" },
          { mode = "n", keys = "<Leader>f", desc = "+Fichiers et recherche" },
          { mode = "n", keys = "<Leader>g", desc = "+Git" },
          { mode = "n", keys = "<Leader>c", desc = "+Code" },
          { mode = "n", keys = "<Leader>r", desc = "+Refactoring" },
          { mode = "n", keys = "<Leader>j", desc = "Sauter à un mot visible" },
          clue.gen_clues.builtin_completion(),
          clue.gen_clues.g(),
          clue.gen_clues.marks(),
          clue.gen_clues.registers(),
          clue.gen_clues.square_brackets(),
          clue.gen_clues.windows(),
          clue.gen_clues.z(),
        },
        window = { delay = 300 },
      })
    end },

  -- Coloration syntaxique fine
  { "nvim-treesitter/nvim-treesitter",
    branch = "main",
    dependencies = { { "nvim-treesitter/nvim-treesitter-textobjects", branch = "main" } },
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

      local function activer_le_repli_par_la_syntaxe()
        vim.wo.foldmethod = "expr"
        vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
        vim.wo.foldlevel = 99
      end

      local function activer_coloration_si_parser_disponible(evenement)
        if vim.api.nvim_buf_line_count(evenement.buf) > LIGNES_MAX_AVANT_RALENTISSEMENT_DU_PARSING then
          return
        end
        local langage = vim.treesitter.language.get_lang(evenement.match)
        local parser_charge, disponible = pcall(vim.treesitter.language.add, langage)
        if parser_charge and disponible then
          pcall(vim.treesitter.start, evenement.buf, langage)
          pcall(activer_le_repli_par_la_syntaxe)
        end
      end

      vim.api.nvim_create_autocmd("FileType", { callback = activer_coloration_si_parser_disponible })
    end },

  -- Autocomplétion
  { "hrsh7th/nvim-cmp",
    dependencies = { "hrsh7th/cmp-nvim-lsp", "L3MON4D3/LuaSnip", "saadparwaiz1/cmp_luasnip",
                     "hrsh7th/cmp-buffer", "hrsh7th/cmp-path",
                     "f3fora/cmp-spell", "windwp/nvim-autopairs", "onsails/lspkind.nvim",
                     "rafamadriz/friendly-snippets" },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      require("luasnip.loaders.from_vscode").lazy_load()

      local function une_suggestion_est_affichee()
        local ok, virtual_text = pcall(require, "codeium.virtual_text")
        return ok and virtual_text.status().state == "completions"
      end

      local function valider_l_entree_ou_descendre_dans_le_menu()
        if cmp.get_selected_entry() then
          return cmp.confirm()
        end
        cmp.select_next_item()
      end

      local function avancer(fallback)
        if cmp.visible() then return valider_l_entree_ou_descendre_dans_le_menu() end
        if luasnip.locally_jumpable(1) then return luasnip.jump(1) end
        if une_suggestion_est_affichee() then return require("codeium.virtual_text").accept() end
        fallback()
      end

      local function reculer(fallback)
        if cmp.visible() then return cmp.select_prev_item() end
        if luasnip.locally_jumpable(-1) then return luasnip.jump(-1) end
        fallback()
      end

      cmp.setup({
        snippet = { expand = function(a) require("luasnip").lsp_expand(a.body) end },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<M-\\>"]    = cmp.mapping(function()
            require("codeium.virtual_text").complete()
          end, { "i" }),
          ["<CR>"]      = cmp.mapping.confirm({ select = true }),
          ["<Tab>"]     = cmp.mapping(avancer, { "i", "s" }),
          ["<S-Tab>"]   = cmp.mapping(reculer, { "i", "s" }),
        }),
        sources = {
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer", keyword_length = 3 },
          { name = "spell",  keyword_length = 3 },
          { name = "path" },
        },
        formatting = {
          format = require("lspkind").cmp_format({
            mode = "symbol_text",
            maxwidth = 50,
            ellipsis_char = "…",
            menu = {
              nvim_lsp = "[LSP]",
              luasnip  = "[Snip]",
              buffer   = "[Buf]",
              spell    = "[Dico]",
              path     = "[Chemin]",
            },
          }),
        },
      })

      require("nvim-autopairs").setup({})
      cmp.event:on("confirm_done", require("nvim-autopairs.completion.cmp").on_confirm_done())
    end },

  -- Signature de la méthode pendant la saisie des arguments
  { "ray-x/lsp_signature.nvim",
    event = "InsertEnter",
    opts = {
      bind = true,
      hint_enable = false,
      floating_window = true,
      handler_opts = { border = "rounded" },
    } },

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

      local function solution_la_plus_proche()
        return vim.fs.find(function(nom) return nom:match("%.sln$") end,
          { upward = true, path = vim.fn.getcwd(), type = "file" })[1]
      end

      local function projets_declares_par_la_solution(solution)
        local projets = {}
        for _, ligne in ipairs(vim.fn.readfile(solution)) do
          local relatif = ligne:match('^Project%b()%s*=%s*"[^"]*",%s*"([^"]+%.csproj)"')
          if relatif then
            table.insert(projets, vim.fs.dirname(solution) .. "/" .. relatif:gsub("\\", "/"))
          end
        end
        return projets
      end

      local NATURE_PAR_SDK = {
        ["Microsoft.NET.Sdk.Web"] = "web",
        ["Microsoft.NET.Sdk.Worker"] = "worker",
      }

      local function nature_executable(csproj)
        if vim.fn.filereadable(csproj) ~= 1 then return nil end
        local contenu = table.concat(vim.fn.readfile(csproj), "\n")
        if contenu:find("Microsoft.NET.Test.Sdk", 1, true) then return nil end
        if contenu:match("<IsTestProject>%s*[Tt]rue") then return nil end
        if contenu:match("<AWSProjectType>%s*Lambda") then return "lambda" end
        local sdk = contenu:match('Sdk="([^"]+)"')
        if sdk and NATURE_PAR_SDK[sdk] then return NATURE_PAR_SDK[sdk] end
        if contenu:match("<OutputType>%s*Exe%s*</OutputType>") then return "console" end
        return nil
      end

      local function projets_de_demarrage()
        local solution = solution_la_plus_proche()
        local candidats = solution and projets_declares_par_la_solution(solution)
          or vim.fn.glob(vim.fn.getcwd() .. "/**/*.csproj", false, true)
        local demarrables = {}
        for _, csproj in ipairs(candidats) do
          local nature = nature_executable(csproj)
          if nature then table.insert(demarrables, { csproj = csproj, nature = nature }) end
        end
        return demarrables
      end

      local function choisir_le_projet_de_demarrage()
        local demarrables = projets_de_demarrage()
        if #demarrables == 0 then
          error("Aucun projet démarrable trouvé depuis " .. vim.fn.getcwd())
        end
        if #demarrables == 1 then return demarrables[1].csproj end
        local choix = require("dap.ui").pick_one(demarrables, "Projet à déboguer : ", function(p)
          return string.format("%s  [%s]", vim.fn.fnamemodify(p.csproj, ":t:r"), p.nature)
        end)
        return choix and choix.csproj
      end

      local projet_retenu_pour_la_session = nil

      local function projet_de_la_session()
        if not projet_retenu_pour_la_session then
          projet_retenu_pour_la_session = choisir_le_projet_de_demarrage()
        end
        if not projet_retenu_pour_la_session then error("Débogage annulé") end
        return projet_retenu_pour_la_session
      end

      local function oublier_le_projet_retenu()
        projet_retenu_pour_la_session = nil
      end

      dap.listeners.after.event_terminated.projet = oublier_le_projet_retenu
      dap.listeners.after.event_exited.projet     = oublier_le_projet_retenu

      local function la_plus_recemment_compilee(a, b)
        return vim.fn.getftime(a) > vim.fn.getftime(b)
      end

      local function abandonner_en_liberant_le_choix(message)
        oublier_le_projet_retenu()
        error(message)
      end

      local function compiler_puis_localiser_la_dll()
        local csproj = projet_de_la_session()
        local sortie = vim.fn.system({ "dotnet", "build", csproj })
        if vim.v.shell_error ~= 0 then
          abandonner_en_liberant_le_choix("Échec de la compilation, débogage annulé :\n" .. sortie)
        end
        local nom = vim.fn.fnamemodify(csproj, ":t:r")
        local compilations = vim.fn.glob(vim.fs.dirname(csproj) .. "/bin/Debug/*/" .. nom .. ".dll", false, true)
        table.sort(compilations, la_plus_recemment_compilee)
        if not compilations[1] then
          abandonner_en_liberant_le_choix("DLL introuvable après compilation de " .. nom)
        end
        return compilations[1]
      end

      local function dossier_du_projet_de_la_session()
        return vim.fs.dirname(projet_de_la_session())
      end

      dap.configurations.cs = {
        {
          type = "coreclr",
          name = "Lancer (build + debug)",
          request = "launch",
          program = compiler_puis_localiser_la_dll,
          cwd = dossier_du_projet_de_la_session,
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

  -- Suggestions en ligne (service hébergé Windsurf)
  { "Exafunction/windsurf.nvim",
    event = "InsertEnter",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("codeium").setup({
        enable_cmp_source = false,
        virtual_text = {
          enabled = true,
          idle_delay = 75,
          key_bindings = {
            accept = false,
            accept_word = "<M-w>",
            accept_line = "<M-l>",
            next = "<M-]>",
            prev = "<M-[>",
            clear = "<M-c>",
          },
        },
      })

      local FICHIERS_A_NE_PAS_ENVOYER = {
        "%.env", "%.env%..*", "%.pem$", "%.key$", "%.cert$", "%.crt$",
        "%.pfx$", "%.p12$", "secrets%.ya?ml$", "appsettings%..*%.json$",
        "%.publishsettings$", "%.dev%.vars$",
      }

      local function le_fichier_peut_partir(chemin)
        local nom = vim.fn.fnamemodify(chemin, ":t")
        for _, motif in ipairs(FICHIERS_A_NE_PAS_ENVOYER) do
          if nom:match(motif) then return false end
        end
        return true
      end

      vim.api.nvim_create_autocmd({ "BufEnter", "BufNewFile" }, {
        group = vim.api.nvim_create_augroup("WindsurfSecrets", { clear = true }),
        callback = function(evenement)
          local codeium = require("codeium")
          local autorise = le_fichier_peut_partir(evenement.file)
          if codeium.s ~= nil and codeium.s.enabled ~= autorise then
            if autorise then codeium.enable() else codeium.disable() end
          end
        end,
      })
    end },

  -- Ajout de paramètre propagé aux appels (plugin maison)
  { "blyscop/csharp-signature.nvim",
    ft = "cs",
    dependencies = { "seblyng/roslyn.nvim" },
    opts = {} },

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
local function le_renommage_couvrirait_toute_la_solution(bufnr)
  local roslyn = vim.lsp.get_clients({ bufnr = bufnr, name = "roslyn" })[1]
  return roslyn == nil or require("csharp-signature").solution_indexed(roslyn)
end

local function renommer_sans_risque_de_portee_partielle()
  if not le_renommage_couvrirait_toute_la_solution(0) then
    return vim.notify(
      "Solution en cours d'indexation : le renommage ne toucherait que le fichier courant.",
      vim.log.levels.WARN, { title = "Renommer" })
  end
  vim.lsp.buf.rename()
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local map = function(k, fn, desc)
      vim.keymap.set("n", k, fn, { buffer = ev.buf, desc = desc })
    end
    map("gd", vim.lsp.buf.definition,      "Aller à la définition")
    map("gr", vim.lsp.buf.references,      "Références")
    map("gi", vim.lsp.buf.implementation,  "Implémentations")
    map("K",  vim.lsp.buf.hover,           "Documentation")
    map("<leader>rn", renommer_sans_risque_de_portee_partielle, "Renommer")
    map("<leader>ca", vim.lsp.buf.code_action, "Action de code")
    map("<leader>rp", function() require("csharp-signature").change_signature() end,
      "Modifier la signature et propager aux appels")
    map("<leader>ra", function() require("csharp-signature").add_parameter() end,
      "Ajouter un paramètre (voie rapide)")
    map("<leader>fm", function() vim.lsp.buf.format() end, "Formater")
    map("[d", function() vim.diagnostic.jump({ count = -1 }) end, "Diagnostic précédent")
    map("]d", function() vim.diagnostic.jump({ count = 1 })  end, "Diagnostic suivant")
  end,
})
