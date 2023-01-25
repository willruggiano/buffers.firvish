---@tag buffers.firvish
---@tag :Buffers
---@brief [[
---Like |:ls| but shows buffers in a normal Neovim buffer.
---When given, bang ! will act like |:ls!| and show all buffers.
---
---Requires firvish.nvim: https://github.com/willruggiano/firvish.nvim
---@brief ]]

local filters = require "buffers-firvish.lib.filters"
local lib = require "buffers-firvish.lib"

local Buffer = require "firvish.lib.buffer"
local BufferList = require "buffers-firvish.lib.bufferlist"

local buffers = {}

---@tag buffers.config
---@brief [[
---The default configuration:
---  open: string (default: edit)
---    How to open the bufferlist. Accepts buffer opening commands like
---    |:edit|, |:vsplit|, |:pedit|, etc.
---
---  excluded_buftypes: table (default: { "quickfix" })
---    Buftypes to exclude from the bufferlist.
---
---  excluded_filetypes: table (default: { "firvish-buffers" })
---    Filetypes to exclude from the bufferlist.
---
---  keymaps: table
---    Keymappings to set in the bufferlist buffer.
---    See |buffers-firvish-keymaps|
---@brief ]]
buffers.config = {
  open = "edit",
  excluded_buftypes = { "quickfix" },
  excluded_filetypes = { "firvish-buffers" },
  keymaps = {
    n = {
      ["-"] = {
        callback = function()
          vim.cmd.bwipeout()
        end,
        desc = "Close the bufferlist",
      },
      ["<CR>"] = {
        callback = function()
          lib.open_buffer "edit"
        end,
        desc = "Open buffer under cursor",
      },
      ["<C-s>"] = {
        callback = function()
          lib.open_buffer "split"
        end,
        desc = ":split buffer under cursor",
      },
      ["<C-v>"] = {
        callback = function()
          lib.open_buffer "vsplit"
        end,
        desc = ":vsplit buffer under cursor",
      },
    },
  },
}

buffers.filename = "firvish://buffers"

buffers.lib = lib

---Setup buffers.firvish
---Creates a user command, |:Buffers|, which can be used to open the bufferlist
---@param opts table
function buffers.setup(opts)
  buffers.config = vim.tbl_deep_extend("force", buffers.config, opts)

  vim.filetype.add {
    filename = {
      [buffers.filename] = "firvish-buffers",
    },
  }

  vim.api.nvim_create_user_command("Buffers", function(args)
    vim.cmd(buffers.config.open .. " " .. buffers.filename)
    buffers.setup_buffer(vim.api.nvim_get_current_buf(), args.bang)
  end, {
    bang = true,
    desc = "Open the buffer list",
  })
end

---Setup the bufferlist buffer
---@param bufnr number the buffer in which to show the bufferlist
---@param show_all_buffers boolean do not filter the bufferlist, like |:ls!|
buffers.setup_buffer = function(bufnr, show_all_buffers)
  local buffer = Buffer:new(bufnr)
  buffer:set_options {
    bufhidden = "wipe",
    buflisted = false,
    buftype = "acwrite",
    swapfile = false,
  }

  local config = buffers.config
  local default_opts = { buffer = bufnr, noremap = true, silent = true }
  for mode, mappings in pairs(config.keymaps) do
    for lhs, opts in pairs(mappings) do
      if opts then
        vim.keymap.set(mode, lhs, opts.callback, vim.tbl_extend("force", default_opts, opts))
      end
    end
  end

  local filter
  if show_all_buffers then
    filter = filters.all
  else
    filter = filters.listed - filters.buftype(config.excluded_buftypes) - filters.filetype(config.excluded_filetypes)
  end
  lib.refresh(filter, buffer)

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    buffer = bufnr,
    callback = function()
      lib.refresh(filter, buffer)
    end,
  })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    callback = function()
      local lines = buffer:get_lines()
      local current = BufferList:new(true, filter)
      local desired = BufferList.parse(lines)
      ---@type BufferList
      ---@diagnostic disable-next-line: assign-type-mismatch
      local bufferlist = current / desired
      for _, buf in bufferlist:iter() do
        if buf:visible() then
          vim.cmd.close { count = vim.fn.bufwinnr(buf.bufnr) }
        end
        vim.cmd.bwipeout(buf.bufnr)
      end
      buffer:set_option("modified", false)
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    buffer = bufnr,
    callback = function()
      lib.refresh(filter, buffer)
    end,
  })
end

return buffers
