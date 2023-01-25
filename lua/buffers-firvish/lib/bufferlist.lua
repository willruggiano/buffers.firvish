local Buffer = require "firvish.lib.buffer"

local sorted_pairs = require("firvish.lib.generators").sorted_pairs

local iter_bufs = function()
  local l = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    table.insert(l, Buffer:new(bufnr))
  end
  return ipairs(l)
end

---@class BufferList
---@field buffers table<string, Buffer>
---@field predicate Filter|function
local BufferList = {}
BufferList.__index = BufferList

---@param with_exising_buffers? boolean
---@param predicate? Filter|function
function BufferList:new(with_exising_buffers, predicate)
  local obj = setmetatable({
    buffers = {},
    predicate = predicate,
  }, BufferList)

  if with_exising_buffers then
    obj:refresh()
  end

  return obj
end

function BufferList:refresh()
  self.buffers = {}
  for _, buffer in iter_bufs() do
    if self.predicate and self.predicate(buffer) then
      self:add(buffer)
    end
  end
  return self
end

---@param buffer Buffer
function BufferList:add(buffer)
  self.buffers[tostring(buffer.bufnr)] = buffer
  return self
end

---@param buffer Buffer
function BufferList:remove(buffer)
  if type(buffer) == "number" then
    self.buffers[tostring(buffer)] = nil
  else
    self.buffers[tostring(buffer.bufnr)] = nil
  end
  return self
end

---Create a new BufferList using only the buffers which satisfy a given predicate
---@param f function a predicate which returns `false` to filter out a buffer
function BufferList:filter(f)
  local copy = BufferList:new()
  for _, buffer in pairs(self.buffers) do
    if f(buffer) then
      copy:add(buffer)
    end
  end
  return copy
end

---Compute the difference between two BufferLists.
---Returns a new BufferList which contains only the buffers that are members
---of lhs and not members of rhs.
---@param lhs BufferList
---@param rhs BufferList
---@return BufferList
function BufferList.__div(lhs, rhs)
  local diff = BufferList:new()
  for _, buffer in lhs:iter() do
    if rhs.buffers[tostring(buffer.bufnr)] == nil then
      diff:add(buffer)
    end
  end
  return diff
end

---@param buffer Buffer
local function make_buffer_line(buffer, n)
  local line = "[" .. buffer.bufnr .. "]" .. string.rep(" ", 1 + #tostring(n) - #tostring(buffer.bufnr))
  if buffer:modified() then
    line = line .. " +"
  end
  local bufname = buffer:name()
  if bufname == "" then
    bufname = "[No Name]"
  end
  line = line .. " " .. bufname
  local buftype = buffer:get_option "buftype"
  if buftype == "quickfix" then
    line = line .. " (quickfix)"
  end
  return line
end

function BufferList:lines()
  local n = self:len()
  local lines = {}
  for _, buffer in pairs(self:sorted()) do
    table.insert(lines, make_buffer_line(buffer, n))
  end
  return lines
end

---@param line string
---@return Buffer
local function parse_buffer_line(line)
  local bufnr = string.match(line, "%[(%d+)%]")
  if not bufnr then
    error("[firvish] Failed to parse buffer line '" .. line .. "'")
  end
  return Buffer:new(bufnr)
end
function BufferList.parse(lines)
  local bufferlist = BufferList:new()
  for _, line in ipairs(lines) do
    if line ~= "" then
      bufferlist:add(parse_buffer_line(line))
    end
  end
  return bufferlist
end

function BufferList:iter()
  return pairs(self.buffers)
end

function BufferList:sorted()
  local buffers = {}
  -- TODO: Sort strings as numbers
  for _, buffer in sorted_pairs(self.buffers) do
    table.insert(buffers, buffer)
  end
  return buffers
end

function BufferList:len()
  return #self.buffers
end

return BufferList
