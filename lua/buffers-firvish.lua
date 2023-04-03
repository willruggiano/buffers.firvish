---@mod buffers-firvish
---@brief [[
---Like |:ls| but implemented using firvish.nvim
---
---Usage:
---------
---Setup:
--->
---require("firvish").setup()
---require("buffers-firvish").setup()
---<
---
---Invoke via |:Firvish|:
---------
--->
---:Firvish[!] buffers [flags]
---<
---
---[!] has mostly the same effect as invoking |:ls| with bang.
---That is, when [!] is included the list will show unlisted buffers
---(the term "unlisted" is a bit confusing then...).
---
---You can go to a specific buffer by moving the cursor to that line,
---and hitting <CR>.
---
---Indicators are the same as |:ls|.
---
---[flags] can be any of the normal |:ls| flags in addition to:
---        n       named buffers
---
---As with |:ls|, combining flags "and"s them together.
---Unlike |:ls|, when [!] is included along with [flags], combining
---flags inverts the normal behavior. Thus:
---
---`:Firvish buffers a+` will list all active, modified buffers
---
---  whereas
---
---`:Firvish! buffers a+` will list all inactive, unmodified buffers
---
---Invoke via `firvish.extensions`:
---------
--->
---require("firvish").extensions.buffers:open()
----- or, to pass arguments (e.g. flags)
---require("firvish.extensions.buffers"):run { ... }
---<
---
---@brief ]]

local BufInfo = require "buffers-firvish.bufinfo"
local Buffer = require "firvish.buffer2"
local bufdelete = require "bufdelete"
local Filter = require "firvish.filter"

local namespace = vim.api.nvim_create_namespace "buffers-firvish"

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
  return buffer_from_line(line)
end

-- stylua: ignore start
local flag_values = {
  ["%+"] = Filter.new(function(bufinfo)
    return bufinfo:modified()
  end),
  ["-"] = Filter.new(function(bufinfo)
    return bufinfo:modifiable() == false
  end),
  ["="] = Filter.new(function(bufinfo)
    return bufinfo:readonly()
  end),
  ["a"] = Filter.new(function(bufinfo)
    return bufinfo:active()
  end),
  ["h"] = Filter.new(function(bufinfo)
    return bufinfo:hidden()
  end),
  ["n"] = Filter.new(function(bufinfo)
    return bufinfo:named()
  end),
  ["u"] = Filter.new(function(bufinfo)
    return bufinfo:listed() == false
  end),
  ["x"] = Filter.new(function(bufinfo)
    return bufinfo:read_errors()
  end),
  ["%%"] = Filter.new(function(bufinfo)
    return bufinfo:current()
  end),
  ["#"] = Filter.new(function(bufinfo)
    return bufinfo:alternate()
  end),
  ["R"] = Filter.new(function(bufinfo)
    local term = bufinfo:terminal()
    return term and term:running() or false
  end),
  ["F"] = Filter.new(function(bufinfo)
    local term = bufinfo:terminal()
    return term and term:finished() or false
  end),
  ["t"] = Filter.new(function(bufinfo)
    return bufinfo:last_used() ~= 0
  end),
}
-- stylua: ignore end

---@return fun(_: BufInfo): boolean
local function make_filter_fn(flags, invert)
  local filter = Filter.new(function()
    return true
  end)

  for pattern, fn in pairs(flag_values) do
    if string.match(flags, pattern) then
      if invert then
        filter = filter - fn
      else
        filter = filter + fn
      end
    end
  end

  ---@diagnostic disable-next-line: return-type-mismatch
  return filter
end

---@param flags string?
---@param invert boolean?
local function filter(flags, invert)
  if flags then
    return make_filter_fn(flags, invert)
  else
    return function(bufinfo)
      if invert then
        return true
      else
        return bufinfo:listed()
      end
    end
  end
end

local function maybe_sort(infos, flags)
  if flags and string.match(flags, "t") then
    table.sort(infos, function(b0, b1)
      -- N.B. b0 will rise to the top if greater than b1
      return b0:last_used() > b1:last_used()
    end)
  end
  return infos
end

---@param flags string?
---@param invert boolean?
local function list_bufs(flags, invert)
  local infos = vim.tbl_map(BufInfo.new, vim.fn.getbufinfo())
  return maybe_sort(vim.tbl_filter(filter(flags, invert), infos), flags)
end

---@param buffer Buffer
---@param flags string?
---@param invert boolean?
local function set_lines(buffer, flags, invert)
  vim.api.nvim_buf_clear_namespace(buffer.bufnr, namespace, 0, -1)

  local lines = {}
  local extmarks = {}
  for _, bufinfo in ipairs(list_bufs(flags, invert)) do
    table.insert(lines, bufinfo:repr())
    local virt_text = bufinfo:virt_text {
      last_used = flags and string.match(flags, "t") and true or false,
    }
    if virt_text then
      table.insert(extmarks, {
        ns_id = namespace,
        line = #lines - 1,
        col = -1,
        opts = {
          virt_text = {
            virt_text,
          },
          virt_text_pos = "right_align",
        },
      })
    end
  end

  buffer:set_lines(lines, {}, extmarks)
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
    },
  }
  obj.options = {
    bufhidden = "hide",
    filetype = "firvish",
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

---@private
---@class ExtensionUpdateOpts
---@field buffer Buffer
---@field flags string?
---@field invert boolean?

---@param opts ExtensionUpdateOpts
function Extension:update(opts)
  set_lines(opts.buffer, opts.flags, opts.invert)
end

---@private
local M = {}

---@package
function M.setup()
  require("firvish").register_extension("buffers", Extension.new())
end

return M
