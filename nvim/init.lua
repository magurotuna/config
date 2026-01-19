-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
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
vim.opt.clipboard = 'unnamedplus,unnamed'
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

-- Keymaps
vim.keymap.set('n', 'j', 'gj')
vim.keymap.set('n', 'k', 'gk')
vim.keymap.set('i', 'jj', '<Esc>', { noremap = true, silent = true })
vim.keymap.set('i', 'jk', '<Esc>', { noremap = true, silent = true })
vim.keymap.set('n', '<Esc><Esc>', ':nohlsearch<CR><Esc>')
vim.keymap.set('n', '<leader><leader>', '<C-^>', { noremap = true })
vim.keymap.set('n', '<leader>w', ':w<CR>')
vim.keymap.set('n', 'n', 'nzz', { noremap = true, silent = true })
vim.keymap.set('n', 'N', 'Nzz', { noremap = true, silent = true })
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
  -- LSP keymaps (only in regular Neovim, not VSCode)
  local lsp_keymap_opts = { noremap = true, silent = true }
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, lsp_keymap_opts)
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, lsp_keymap_opts)
  vim.keymap.set('n', 'gy', vim.lsp.buf.type_definition, lsp_keymap_opts)
  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, lsp_keymap_opts)
  vim.keymap.set('n', '<leader>a', vim.lsp.buf.code_action, lsp_keymap_opts)
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, lsp_keymap_opts)
  vim.keymap.set('n', 'gh', vim.lsp.buf.hover, lsp_keymap_opts)
  vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, lsp_keymap_opts)
  vim.keymap.set('n', ']d', vim.diagnostic.goto_next, lsp_keymap_opts)
  vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, lsp_keymap_opts)
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
          variant = 'main',
          dark_variant = 'main',
        })
        vim.cmd('colorscheme rose-pine')
      end,
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
      branch = 'master',
      cond = not vim.g.vscode,
      lazy = false,
      build = ':TSUpdate',
      config = function()
        require('nvim-treesitter').setup({
          install_dir = vim.fn.stdpath('data') .. '/site',
        })
        -- Install parsers
        require('nvim-treesitter').install({
          'lua', 'vim', 'vimdoc', 'query',
          'javascript', 'typescript', 'tsx',
          'rust', 'go', 'python',
          'json', 'yaml', 'toml', 'markdown',
          'html', 'css', 'bash', 'nix',
        })
      end,
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

        vim.lsp.config('ts_ls', { capabilities = capabilities })
        vim.lsp.config('rust_analyzer', { capabilities = capabilities })
        vim.lsp.config('gopls', { capabilities = capabilities })
        vim.lsp.config('pyright', { capabilities = capabilities })

        -- Enable the servers
        vim.lsp.enable({ 'lua_ls', 'ts_ls', 'rust_analyzer', 'gopls', 'pyright' })
      end,
    },

    -- Completion (skip in VSCode)
    {
      'hrsh7th/nvim-cmp',
      cond = not vim.g.vscode,
      dependencies = {
        'hrsh7th/cmp-nvim-lsp',
        'hrsh7th/cmp-buffer',
        'hrsh7th/cmp-path',
      },
      config = function()
        local cmp = require('cmp')
        cmp.setup({
          mapping = cmp.mapping.preset.insert({
            ['<C-b>'] = cmp.mapping.scroll_docs(-4),
            ['<C-f>'] = cmp.mapping.scroll_docs(4),
            ['<C-Space>'] = cmp.mapping.complete(),
            ['<C-e>'] = cmp.mapping.abort(),
            ['<CR>'] = cmp.mapping.confirm({ select = true }),
            ['<Tab>'] = cmp.mapping.select_next_item(),
            ['<S-Tab>'] = cmp.mapping.select_prev_item(),
          }),
          sources = cmp.config.sources({
            { name = 'nvim_lsp' },
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
      config = function()
        local builtin = require('telescope.builtin')
        vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Find files' })
        vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Live grep' })
        vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Buffers' })
        vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Help tags' })
        vim.keymap.set('n', '<C-p>', builtin.find_files, { desc = 'Find files' })
      end,
    },
  },
  install = { colorscheme = { 'rose-pine' } },
  checker = { enabled = true },
})

