local lib = require "firvish.lib"
local BufInfo = require "buffers-firvish.bufinfo"

local Buffer = {}
Buffer.__index = Buffer

function Buffer.new(bufnr)
  return setmetatable({ bufnr = bufnr }, Buffer)
end

local function show_last_used(opts)
  if opts then
    local flags = opts[1]
    if flags then
      if string.match(flags, "t") then
        return true
      end
    end
  end
  return false
end

function Buffer:to_line(state)
  local bufinfo = BufInfo.new(self.bufnr)
  local line = bufinfo:repr()
  local virt_text = bufinfo:virt_text {
    last_used = show_last_used(state.opts),
  }
  return line, virt_text
end

---@param line string
function Buffer.from_line(line)
  local ok, bufnr = pcall(tonumber, string.match(line, "(%d+)"))
  if not ok then
    error "Failed to parse buffer line"
  end
  return Buffer.new(bufnr)
end

---@param other Buffer
function Buffer:equals(other)
  return self.bufnr == other.bufnr
end

function Buffer:delete(force)
  vim.api.nvim_buf_delete(self.bufnr, { force = force or false })
end

---@param state table
local function make_buffer_list(state)
  local buffers = {}
  local cmd = state.invert and "ls!" or "ls"
  if state.opts and #state.opts > 0 then
    cmd = cmd .. " " .. state.opts[1]
  end
  local output = vim.api.nvim_exec2(cmd, { output = true })
  for line in string.gmatch(output.output, "([^\n]+)") do
    table.insert(buffers, Buffer.from_line(line))
  end
  return buffers
end

local M = {}

local function open_buffer_under_cursor()
  local line = lib.get_cursor_line()
  local buffer = Buffer.from_line(line)
  lib.open_buffer(buffer.bufnr)
end

function M.setup()
  require("firvish").register_extension_t("buffers_t", Buffer, {
    buffer = {
      name = "[Firvish Buffers]",
      keymap = {
        n = {
          ["<CR>"] = {
            callback = open_buffer_under_cursor,
            desc = "Open buffer under cursor",
          },
        },
      },
    },
    generator = make_buffer_list,
    operations = {
      delete = true,
    },
    state = {
      -- TODO: These should be the defaults
      opts = {},
      invert = false,
    },
  })
end

return M
