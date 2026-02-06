-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out,                            "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Setup several stuff
vim.g.mapleader = ' '

vim.api.nvim_command('filetype plugin indent on')
vim.opt.encoding = 'utf-8'
vim.opt.number = true
vim.opt.ruler = true
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.signcolumn = 'yes'
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.scrolloff = 10  -- keep 10 lines above/below cursor

-- Use OSC52 for clipboard
do
  local ok, osc52 = pcall(require, 'vim.ui.clipboard.osc52')
  if ok then
    vim.g.clipboard = {
      name = 'osc52',
      copy = {
        ['+'] = osc52.copy('+'),
        ['*'] = osc52.copy('*'),
      },
      paste = {
        ['+'] = osc52.paste('+'),
        ['*'] = osc52.paste('*'),
      },
    }
  end
end
vim.opt.clipboard = 'unnamedplus'
vim.opt.termguicolors = true
vim.opt.autoread = true
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.showmatch = true
vim.opt.list = true
vim.opt.listchars = 'tab:▸-,trail:-,extends:»,precedes:«,nbsp:%'
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true
vim.opt.gdefault = true
vim.opt.wrapscan = true
vim.opt.hlsearch = true
vim.opt.hidden = true
vim.opt.showcmd = true
vim.opt.relativenumber = true
vim.opt.mouse = 'a'
vim.opt.undofile = true
vim.opt.updatetime = 300
vim.opt.pumblend = 15
vim.opt.numberwidth = 5
vim.opt.colorcolumn = '80'
vim.opt.cursorline = true

-- Auto-reload files when changed externally (not needed in VSCode)
if not vim.g.vscode then
  require('config.autoreload').setup()
end

-- Keymaps
vim.keymap.set('n', 'j', 'gj')
vim.keymap.set('n', 'k', 'gk')
vim.keymap.set('i', 'jj', '<Esc>', { noremap = true, silent = true })
vim.keymap.set('i', 'jk', '<Esc>', { noremap = true, silent = true })
vim.keymap.set('n', '<Esc>', ':nohlsearch<CR>')
vim.keymap.set('n', '<leader><leader>', '<C-^>', { noremap = true, desc = 'Alternate buffer' })
vim.keymap.set('n', '<leader>w', ':w<CR>', { desc = 'Save file' })
vim.keymap.set('n', 'n', 'nzz', { noremap = true, silent = true })
vim.keymap.set('n', 'N', 'Nzz', { noremap = true, silent = true })
-- Quickfix navigation
vim.keymap.set('n', ']q', ':cnext<CR>zz', { desc = 'Next quickfix' })
vim.keymap.set('n', '[q', ':cprev<CR>zz', { desc = 'Prev quickfix' })
vim.keymap.set('n', ']Q', ':clast<CR>zz', { desc = 'Last quickfix' })
vim.keymap.set('n', '[Q', ':cfirst<CR>zz', { desc = 'First quickfix' })
vim.keymap.set('n', '<leader>q', function()
  local qf_exists = false
  for _, win in pairs(vim.fn.getwininfo()) do
    if win.quickfix == 1 then
      qf_exists = true
      break
    end
  end
  if qf_exists then vim.cmd('cclose') else vim.cmd('copen') end
end, { desc = 'Toggle quickfix' })
vim.keymap.set('n', '*', '*zz', { noremap = true, silent = true })
vim.keymap.set('n', '#', '#zz', { noremap = true, silent = true })
vim.keymap.set('n', 'g*', 'g*zz', { noremap = true, silent = true })
vim.keymap.set('', 'H', '^', { silent = true })
vim.keymap.set('', 'L', '$', { silent = true })
vim.keymap.set('n', 's', '<Nop>', { noremap = true })
vim.keymap.set('n', 'sj', '<C-w>j', { noremap = true })
vim.keymap.set('n', 'sk', '<C-w>k', { noremap = true })
vim.keymap.set('n', 'sl', '<C-w>l', { noremap = true })
vim.keymap.set('n', 'sh', '<C-w>h', { noremap = true })
vim.keymap.set('n', 'sJ', '<C-w>J', { noremap = true })
vim.keymap.set('n', 'sK', '<C-w>K', { noremap = true })
vim.keymap.set('n', 'sL', '<C-w>L', { noremap = true })
vim.keymap.set('n', 'sH', '<C-w>H', { noremap = true })
vim.keymap.set('n', 'ss', ':<C-u>sp<CR>', { noremap = true })
vim.keymap.set('n', 'sv', ':<C-u>vs<CR>', { noremap = true })
vim.keymap.set('n', 'sq', ':<C-u>q<CR>', { noremap = true })
vim.keymap.set('n', 'sQ', ':<C-u>bd<CR>', { noremap = true })
vim.keymap.set('n', 'st', ':<C-u>tabnew<CR>', { noremap = true })
vim.keymap.set('n', 'sn', 'gt', { noremap = true })
vim.keymap.set('n', 'sp', 'gT', { noremap = true })
vim.keymap.set('c', '<C-a>', '<Home>', { noremap = true })
vim.keymap.set('c', '<C-b>', '<Left>', { noremap = true })
vim.keymap.set('c', '<C-d>', '<Del>', { noremap = true })
vim.keymap.set('c', '<C-e>', '<End>', { noremap = true })
vim.keymap.set('c', '<C-f>', '<Right>', { noremap = true })
vim.keymap.set('c', '<C-n>', '<Down>', { noremap = true })
vim.keymap.set('c', '<C-p>', '<Up>', { noremap = true })
vim.keymap.set('c', '<M-b>', '<S-Left>', { noremap = true })
vim.keymap.set('c', '<M-f>', '<S-Right>', { noremap = true })

if vim.g.vscode then
  local vscode = require('vscode')

  -- Show the list of code actions provided by LSP
  vim.keymap.set('n', '<leader>a', function()
    vscode.action("editor.action.quickFix")
  end)

  -- Jump to the next diagnostic
  vim.keymap.set('n', 'g[', function()
    vscode.action('editor.action.marker.nextInFiles')
  end)

  -- Jump to the previous diagnostic
  vim.keymap.set('n', 'g]', function()
    vscode.action('editor.action.marker.prevInFiles')
  end)

  -- Focus the next editor group
  vim.keymap.set('n', 'sl', function()
    vscode.action('workbench.action.focusNextGroup')
  end)

  -- Focus the previous editor group
  vim.keymap.set('n', 'sh', function()
    vscode.action('workbench.action.focusPreviousGroup')
  end)
else
  -- LSP keymaps (non-Telescope ones, only in regular Neovim)
  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, { desc = 'Rename symbol' })
  vim.keymap.set('n', '<leader>a', vim.lsp.buf.code_action, { desc = 'Code action' })
  vim.keymap.set('n', 'gh', function()
    vim.lsp.buf.hover({ border = 'rounded' })
  end, { desc = 'Hover documentation' })
  vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Previous diagnostic' })
  vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Next diagnostic' })
  vim.keymap.set('n', '<leader>e', function()
    vim.diagnostic.open_float({ border = 'rounded' })
  end, { desc = 'Show diagnostics' })
end

-- Setup lazy.nvim
require('lazy').setup({
  spec = {
    -- Colorscheme (skip in VSCode)
    {
      'rose-pine/neovim',
      name = 'rose-pine',
      cond = not vim.g.vscode,
      priority = 1000,
      config = function()
        require('rose-pine').setup({
          variant = 'moon',
          dark_variant = 'moon',
          styles = {
            transparency = true,
          },
        })
        vim.cmd('colorscheme rose-pine')
      end,
    },

    -- Statusline (skip in VSCode)
    {
      'nvim-lualine/lualine.nvim',
      cond = not vim.g.vscode,
      dependencies = { 'nvim-tree/nvim-web-devicons' },
      opts = {
        options = {
          theme = 'rose-pine',
        },
      },
    },

    -- Surround (works in VSCode too)
    {
      'echasnovski/mini.surround',
      version = '*',
      opts = {
        mappings = {
          highlight = 'sH',
        },
      },
    },

    -- Treesitter (skip in VSCode)
    {
      'nvim-treesitter/nvim-treesitter',
      cond = not vim.g.vscode,
      build = ':TSUpdate',
      config = function()
        -- Enable treesitter highlighting for all filetypes with a parser
        vim.api.nvim_create_autocmd('FileType', {
          callback = function()
            if pcall(vim.treesitter.start) then
              -- Successfully started treesitter
            end
          end,
        })
      end,
    },

    -- Sticky context (shows function/class name at top)
    {
      'nvim-treesitter/nvim-treesitter-context',
      cond = not vim.g.vscode,
      config = function()
        require('treesitter-context').setup({
          enable = true,
          max_lines = 3,
          mode = 'topline',  -- context based on top visible line, not cursor
          separator = '─',
        })
        -- Style the separator
        vim.api.nvim_set_hl(0, 'TreesitterContextSeparator', { fg = '#666666' })
      end,
    },

    -- Breadcrumb navigation in winbar (skip in VSCode)
    {
      'Bekaboo/dropbar.nvim',
      cond = not vim.g.vscode,
      opts = {},
    },

    -- Scrollbar (skip in VSCode)
    {
      'petertriho/nvim-scrollbar',
      cond = not vim.g.vscode,
      opts = {
        handle = {
          color = '#5c6370',
        },
        marks = {
          Cursor = { text = '─', color = '#61afef' },
          Search = { text = { '▬', '▬' }, color = '#e5c07b' },
          Error = { text = { '▬', '▬' }, color = '#e06c75' },
          Warn = { text = { '▬', '▬' }, color = '#e5c07b' },
          Info = { text = { '▬', '▬' }, color = '#61afef' },
          Hint = { text = { '▬', '▬' }, color = '#98c379' },
          Misc = { text = { '▬', '▬' }, color = '#c678dd' },
        },
      },
    },

    -- Indent guides (skip in VSCode)
    {
      'lukas-reineke/indent-blankline.nvim',
      cond = not vim.g.vscode,
      main = 'ibl',
      opts = {},
    },

    -- Git signs in gutter (skip in VSCode)
    {
      'lewis6991/gitsigns.nvim',
      cond = not vim.g.vscode,
      opts = {},
    },

    -- LSP progress indicator (skip in VSCode)
    {
      'j-hui/fidget.nvim',
      cond = not vim.g.vscode,
      opts = {},
    },

    -- LSP (skip in VSCode)
    -- nvim-lspconfig provides server configs in lsp/ directory
    -- We use Neovim 0.11's native vim.lsp.config() API
    {
      'neovim/nvim-lspconfig',
      cond = not vim.g.vscode,
      dependencies = {
        'hrsh7th/cmp-nvim-lsp',
      },
      config = function()
        local capabilities = require('cmp_nvim_lsp').default_capabilities()

        -- Configure LSP servers using Neovim 0.11 API
        vim.lsp.config('lua_ls', {
          capabilities = capabilities,
          settings = {
            Lua = {
              diagnostics = {
                globals = { 'vim' },
              },
            },
          },
        })

        -- TypeScript: only start if NOT a Deno project
        vim.lsp.config('ts_ls', {
          capabilities = capabilities,
          root_markers = { 'package.json', 'tsconfig.json', 'jsconfig.json' },
          root_dir = function(bufnr, on_dir)
            local fname = vim.api.nvim_buf_get_name(bufnr)
            local root = vim.fs.root(bufnr, { 'package.json', 'tsconfig.json', 'jsconfig.json' })
            -- Don't start if deno.json exists
            local deno_root = vim.fs.root(bufnr, { 'deno.json', 'deno.jsonc' })
            if deno_root then return end
            on_dir(root)
          end,
        })

        -- Deno: only start if deno.json exists
        vim.lsp.config('denols', {
          capabilities = capabilities,
          root_markers = { 'deno.json', 'deno.jsonc' },
          settings = {
            deno = {
              enable = true,
              lint = true,
              unstable = true,
            },
          },
        })

        -- Handle deno: virtual document URIs (e.g. deno:/asset/lib.dom.d.ts)
        vim.api.nvim_create_autocmd('BufReadCmd', {
          pattern = 'deno:/*',
          callback = function(ev)
            local clients = vim.lsp.get_clients({ name = 'denols' })
            if #clients == 0 then return end
            local result = clients[1]:request_sync('deno/virtualTextDocument', {
              textDocument = { uri = ev.match },
            }, 5000)
            if result and result.result then
              local lines = vim.split(result.result, '\n')
              vim.api.nvim_buf_set_lines(ev.buf, 0, -1, false, lines)
              vim.bo[ev.buf].readonly = true
              vim.bo[ev.buf].modified = false
              vim.bo[ev.buf].modifiable = false
              vim.bo[ev.buf].buftype = 'nofile'
              if ev.match:match('%.ts$') then
                vim.bo[ev.buf].filetype = 'typescript'
              elseif ev.match:match('%.js$') then
                vim.bo[ev.buf].filetype = 'javascript'
              end
            end
          end,
        })

        vim.lsp.config('rust_analyzer', { capabilities = capabilities })
        vim.lsp.config('gopls', { capabilities = capabilities })
        vim.lsp.config('pyright', { capabilities = capabilities })
        vim.lsp.config('zls', { capabilities = capabilities })

        -- Enable the servers
        vim.lsp.enable({ 'lua_ls', 'ts_ls', 'denols', 'rust_analyzer', 'gopls', 'pyright', 'zls' })
      end,
    },

    -- Copilot (skip in VSCode)
    {
      'zbirenbaum/copilot.lua',
      cond = not vim.g.vscode,
      cmd = 'Copilot',
      event = 'InsertEnter',
      opts = {
        suggestion = { enabled = false }, -- disable inline suggestions, use cmp instead
        panel = { enabled = false },
      },
    },
    {
      'zbirenbaum/copilot-cmp',
      cond = not vim.g.vscode,
      dependencies = { 'zbirenbaum/copilot.lua' },
      opts = {},
    },

    -- Completion (skip in VSCode)
    {
      'hrsh7th/nvim-cmp',
      cond = not vim.g.vscode,
      dependencies = {
        'hrsh7th/cmp-nvim-lsp',
        'hrsh7th/cmp-buffer',
        'hrsh7th/cmp-path',
        'zbirenbaum/copilot-cmp',
      },
      config = function()
        local cmp = require('cmp')
        cmp.setup({
          mapping = cmp.mapping.preset.insert({
            ['<C-b>'] = cmp.mapping.scroll_docs(-4),
            ['<C-f>'] = cmp.mapping.scroll_docs(4),
            ['<C-Space>'] = cmp.mapping.complete(),
            ['<C-e>'] = cmp.mapping.abort(),
            ['<CR>'] = cmp.mapping.confirm({ select = false }),
            ['<Tab>'] = cmp.mapping.select_next_item(),
            ['<S-Tab>'] = cmp.mapping.select_prev_item(),
          }),
          sources = cmp.config.sources({
            { name = 'copilot',  group_index = 1 },
            { name = 'nvim_lsp', group_index = 1 },
          }, {
            { name = 'buffer' },
            { name = 'path' },
          }),
        })
      end,
    },

    -- Autopairs (skip in VSCode)
    {
      'windwp/nvim-autopairs',
      cond = not vim.g.vscode,
      event = 'InsertEnter',
      config = function()
        local autopairs = require('nvim-autopairs')
        autopairs.setup({})

        -- Integration with nvim-cmp
        local cmp_autopairs = require('nvim-autopairs.completion.cmp')
        local cmp = require('cmp')
        cmp.event:on('confirm_done', cmp_autopairs.on_confirm_done())
      end,
    },

    -- Telescope (skip in VSCode)
    {
      'nvim-telescope/telescope.nvim',
      cond = not vim.g.vscode,
      tag = 'v0.2.1',
      dependencies = { 'nvim-lua/plenary.nvim' },
      keys = {
        { '<leader>ff', function() require('telescope.builtin').find_files() end, desc = 'Find files' },
        { '<leader>fg', function() require('telescope.builtin').live_grep() end, desc = 'Live grep' },
        { '<leader>fb', function() require('telescope.builtin').buffers() end, desc = 'Buffers' },
        { '<leader>fh', function() require('telescope.builtin').help_tags() end, desc = 'Help tags' },
        { '<C-p>', function() require('telescope.builtin').find_files() end, desc = 'Find files' },
      },
      config = function()
        local actions = require('telescope.actions')
        require('telescope').setup({
          defaults = {
            sorting_strategy = 'ascending', -- input at top, results below
            layout_strategy = 'flex', -- auto-switch between horizontal/vertical
            layout_config = {
              prompt_position = 'top',
              flex = {
                flip_columns = 120, -- use vertical layout when width < 120
              },
              horizontal = {
                prompt_position = 'top',
              },
              vertical = {
                prompt_position = 'top',
                preview_height = 0.4,
              },
            },
            -- Smart case: case-insensitive unless uppercase is used
            vimgrep_arguments = {
              'rg', '--color=never', '--no-heading', '--with-filename',
              '--line-number', '--column', '--smart-case',
            },
          },
          pickers = {
            find_files = {
              hidden = true,
            },
            buffers = {
              mappings = {
                n = {
                  ['dd'] = actions.delete_buffer,
                },
              },
            },
          },
        })
        -- LSP keymaps via Telescope
        local builtin = require('telescope.builtin')
        vim.keymap.set('n', 'gd', builtin.lsp_definitions, { desc = 'Go to definition' })
        vim.keymap.set('n', 'gi', builtin.lsp_implementations, { desc = 'Go to implementation' })
        vim.keymap.set('n', 'gy', builtin.lsp_type_definitions, { desc = 'Go to type definition' })
        vim.keymap.set('n', 'gr', builtin.lsp_references, { desc = 'Find references' })
      end,
    },

    -- File explorer (skip in VSCode)
    {
      "stevearc/oil.nvim",
      cond = not vim.g.vscode,
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        require("oil").setup({
          view_options = {
            show_hidden = true,
          },
        })
        vim.keymap.set("n", "-", "<cmd>Oil<cr>", { desc = "Open parent directory" })
        vim.keymap.set("n", "<leader>t", "<cmd>Oil<cr>", { desc = "Open file explorer" })
      end,
    },

    -- Formatter (skip in VSCode)
    {
      "stevearc/conform.nvim",
      cond = not vim.g.vscode,
      event = { "BufWritePre" },
      cmd = { "ConformInfo" },
      config = function()
        -- Detect JS/TS formatter based on project config (searches upward)
        local function find_config(names)
          local found = vim.fs.find(names, {
            upward = true,
            path = vim.fn.expand('%:p:h'),
          })
          return #found > 0
        end

        local function js_formatter()
          if find_config({ "deno.json", "deno.jsonc" }) then
            return { "deno_fmt" }
          elseif find_config({ "biome.json", "biome.jsonc" }) then
            return { "biome" }
          else
            return { "prettier" }
          end
        end

        require("conform").setup({
          formatters_by_ft = {
            lua = { "stylua" },
            javascript = js_formatter,
            typescript = js_formatter,
            javascriptreact = js_formatter,
            typescriptreact = js_formatter,
            json = js_formatter,
            yaml = { "prettier" },
            markdown = { "prettier" },
            html = { "prettier" },
            css = { "prettier" },
            rust = { "rustfmt" },
            go = { "gofmt" },
            python = { "ruff_format" },
            nix = { "nixfmt" },
            zig = { "zigfmt" },
          },
          format_on_save = {
            timeout_ms = 500,
            lsp_fallback = true,
          },
        })
        vim.keymap.set({ "n", "v" }, "<leader>fm", function()
          require("conform").format({ async = true, lsp_fallback = true })
        end, { desc = "Format buffer" })
      end,
    },

    -- Highlight word under cursor (skip in VSCode)
    {
      "RRethy/vim-illuminate",
      cond = not vim.g.vscode,
      config = function()
        require("illuminate").configure({
          delay = 200,
          filetypes_denylist = { "oil", "TelescopePrompt" },
        })
      end,
    },

    -- Show available keybindings (skip in VSCode)
    {
      "folke/which-key.nvim",
      cond = not vim.g.vscode,
      event = "VeryLazy",
      opts = {
        delay = 500, -- ms before popup shows (default uses timeoutlen)
      },
    },
  },
  install = { colorscheme = { 'rose-pine' } },
  checker = { enabled = true },
})
