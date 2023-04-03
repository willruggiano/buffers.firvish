local BufInfo = require "buffers-firvish.bufinfo"
local Buffer = require "firvish.buffer2"
local bufdelete = require "bufdelete"

local function reconstruct(line)
  local match = string.match(line, "(%d+)")
  if match ~= nil then
    return tonumber(match)
  else
    error("Failed to parse line: " .. line .. "")
  end
end

local function buffer_from_line(line)
  local bufnr = reconstruct(line)
  return Buffer.from(bufnr)
end

local function reconstruct_from_buffer(buffer)
  local buffers = {}
  for _, line in ipairs(buffer:get_lines()) do
    table.insert(buffers, buffer_from_line(line))
  end
  return buffers
end

local function buffer_at_cursor()
  local line = require("firvish.lib").get_cursor_line()
  vim.pretty_print(line)
  return buffer_from_line(line)
end

-- stylua: ignore start
local flag_values = {
  ["%+"] = function(bufinfo)
    return bufinfo:modified()
  end,
  ["-"] = function(bufinfo)
    return bufinfo:modifidable() == false
  end,
  ["="] = function(bufinfo)
    return bufinfo:readonly()
  end,
  ["a"] = function(bufinfo)
    return bufinfo:active()
  end,
  ["u"] = function(bufinfo)
    return bufinfo:listed() == false
  end,
  ["h"] = function(bufinfo)
    return bufinfo:hidden()
  end,
  ["x"] = function(bufinfo)
    return bufinfo:read_errors()
  end,
  ["%%"] = function(bufinfo)
    return bufinfo:current()
  end,
  ["#"] = function(bufinfo)
    return bufinfo:alternate()
  end,
  ["R"] = function(bufinfo)
    -- TODO: implement terminal buffer handling
    return false
  end,
  ["F"] = function(bufinfo)
    -- TODO: implement terminal buffer handling
    return false
  end,
  ["t"] = function(bufinfo)
    -- TODO: implement last used/sorting
    return false
  end,
}
-- stylua: ignore end

---@param flags string?
local function filter(flags)
  if flags then
    return function(bufinfo)
      for pattern, fn in pairs(flag_values) do
        if string.match(flags, pattern) then
          if fn(bufinfo) == false then
            return false
          end
        end
      end
      return true
    end
  else
    return function(bufinfo)
      -- TODO: Some sort of default, akin to :ls
      return true
    end
  end
end

---@param flags string?
---@param dict {string: boolean}?
local function list_bufs(flags, dict)
  local infos = vim.tbl_map(BufInfo.new, dict and vim.fn.getbufinfo(dict) or vim.fn.getbufinfo())
  return vim.tbl_filter(filter(flags), infos)
end

---@param buffer Buffer
---@param flags string?
---@param dict {string: boolean}?
local function set_lines(buffer, flags, dict)
  local lines = {}
  for _, bufinfo in ipairs(list_bufs(flags, dict)) do
    table.insert(lines, bufinfo:repr())
  end

  buffer:set_lines(lines)
  buffer.opt.modified = false
end

local function make_lookup_table(buffers)
  local t = {}
  for _, buffer in ipairs(buffers) do
    t[tostring(buffer.bufnr)] = buffer
  end
  return t
end

---@param original BufInfo[]
---@param target Buffer[]
local function compute_difference(original, target)
  local lookup = make_lookup_table(target)
  local diff = {}
  for _, bufinfo in ipairs(original) do
    if lookup[tostring(bufinfo:bufnr())] == nil then
      table.insert(diff, bufinfo:bufnr())
    end
  end
  return diff
end

local Extension = {}
Extension.__index = Extension

Extension.bufname = "firvish://buffers"

function Extension.new()
  local obj = {}

  obj.keymaps = {
    n = {
      ["<CR>"] = {
        callback = function()
          local buffer = buffer_at_cursor()
          vim.cmd.buffer(buffer.bufnr)
        end,
        desc = "Open the buffer under the cursor",
      },
      ["K"] = {
        callback = function()
          local buffer = buffer_at_cursor()
          print(buffer.bufnr, buffer.opt.modified and "+" or " ", buffer:name())
        end,
        desc = "Show buffer meta information",
      },
    },
  }
  obj.options = {
    bufhidden = "hide",
  }

  return setmetatable(obj, Extension)
end

function Extension:on_buf_enter(buffer)
  set_lines(buffer)
end

function Extension:on_buf_write_cmd(buffer)
  -- TODO: state.flags, state.dict?
  local current = list_bufs()
  local desired = reconstruct_from_buffer(buffer)
  local diff = compute_difference(current, desired)
  for _, bufnr in ipairs(diff) do
    bufdelete.bufwipeout(bufnr, vim.v.cmdbang)
  end
  buffer.opt.modified = false
end

function Extension:on_buf_write_post(buffer)
  set_lines(buffer)
end

---@class ExtensionUpdateOpts
---@field buffer Buffer
---@field flags string?
---@field dict {string: boolean}?

---@param opts ExtensionUpdateOpts
function Extension:update(opts)
  set_lines(opts.buffer, opts.flags, opts.dict)
end

local M = {}

function M.setup()
  require("firvish").register_extension("buffers", Extension.new())
end

return M
