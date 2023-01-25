local Filter = require "firvish.lib.filter"

local FilterAll = Filter:new(function()
  return true
end)

---@param buffer Buffer
local FilterListed = Filter:new(function(buffer)
  return buffer:listed()
end)

---@param buffer Buffer
local FilterModified = Filter:new(function(buffer)
  return buffer:modified()
end)

---@return Filter
local function FilterBuftype(buftypes)
  ---@param buffer Buffer
  return Filter:new(function(buffer)
    if type(buftypes) == "string" then
      return buffer:get_option "buftype" == buftypes
    else
      return vim.tbl_contains(buftypes, buffer:get_option "buftype")
    end
  end)
end

---@return Filter
local function FilterFiletype(filetypes)
  ---@param buffer Buffer
  return Filter:new(function(buffer)
    if type(filetypes) == "string" then
      return buffer:filetype() == filetypes
    else
      return vim.tbl_contains(filetypes, buffer:filetype())
    end
  end)
end

return {
  all = FilterAll,
  listed = FilterListed,
  modified = FilterModified,
  buftype = FilterBuftype,
  filetype = FilterFiletype,
}
