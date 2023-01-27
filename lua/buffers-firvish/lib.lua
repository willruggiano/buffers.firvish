local firvish = require "firvish.lib"

local Buffer = require "firvish.types.buffer"
local BufferList = require "buffers-firvish.lib.bufferlist"

local lib = {}

---Refresh the buffer list
---@param filter Filter|function only show buffers that satisfy the given filter
---@param buffer? Buffer
lib.refresh = function(filter, buffer)
  if buffer == nil then
    buffer = Buffer:new(vim.api.nvim_get_current_buf())
  end
  local bufferlist = BufferList:new(true, filter)
  buffer:set_lines(bufferlist:lines())
  buffer:set_option("modified", false)
end

---Open the selected buffer
---@param how? string how to open the buffer, e.g. `:edit`, `:split`, `:vert pedit`, etc
lib.open_buffer = function(how)
  local buffer = lib.buffer_at_cursor()
  buffer:open(how)
end

---Get the Buffer at the current cursor position
---@return Buffer
lib.buffer_at_cursor = function()
  local line = firvish.get_cursor_line()
  return lib.buffer_at_line(line)
end

lib.buffer_at_line = function(line)
  local bufnr = lib.parse_line(line)
  return Buffer:new(bufnr)
end

lib.parse_line = function(line)
  local match = string.match(line, "%[(%d+)%]")
  if match ~= nil then
    return tonumber(match)
  else
    error("Failed to get buffer from '" .. line .. "'")
  end
end

return lib
