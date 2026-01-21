-- Auto-reload files when changed externally using filesystem events (like VSCode)
-- Uses libuv's fs_event for instant detection instead of polling

local M = {}

local watchers = {}

local function start_watching(bufnr)
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  -- Skip if no file, already watching, or special buffer
  if filepath == '' or watchers[bufnr] then return end
  if not vim.uv.fs_stat(filepath) then return end

  local w = vim.uv.new_fs_event()
  if not w then return end

  w:start(filepath, {}, vim.schedule_wrap(function(err, _, _)
    if err then return end

    -- Debounce: stop and restart watcher (file may have been replaced)
    if watchers[bufnr] then
      watchers[bufnr]:stop()
      watchers[bufnr] = nil
    end

    -- Check if buffer is still valid
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    -- Check if file still exists (handles rename/delete)
    local current_path = vim.api.nvim_buf_get_name(bufnr)
    if not vim.uv.fs_stat(current_path) then
      -- File was deleted or renamed, don't reload or restart watcher
      return
    end

    -- Reload if buffer is not modified
    if not vim.bo[bufnr].modified then
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd('checktime')
      end)
    end

    -- Restart watcher
    vim.defer_fn(function()
      start_watching(bufnr)
    end, 100)
  end))

  watchers[bufnr] = w
end

function M.setup()
  -- Start watching when buffer is read
  vim.api.nvim_create_autocmd('BufReadPost', {
    callback = function(args)
      start_watching(args.buf)
    end,
  })

  -- Stop watching when buffer is deleted
  vim.api.nvim_create_autocmd('BufDelete', {
    callback = function(args)
      local w = watchers[args.buf]
      if w then
        w:stop()
        watchers[args.buf] = nil
      end
    end,
  })

  -- Notify when file changes
  vim.api.nvim_create_autocmd('FileChangedShellPost', {
    callback = function()
      vim.notify('File changed on disk. Buffer reloaded.', vim.log.levels.WARN)
    end,
  })
end

return M
