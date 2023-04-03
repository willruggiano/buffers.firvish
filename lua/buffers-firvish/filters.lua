local Filter = require "firvish.filter"

local FilterAll = Filter:new(function()
  return true
end)

---@param buffer Buffer
local FilterListed = Filter:new(function(buffer)
  return buffer.opt.buflisted == true
end)

---@param buffer Buffer
local FilterModified = Filter:new(function(buffer)
  return buffer.opt.modified == true
end)

---@return Filter
local function FilterBuftype(buftypes)
  ---@param buffer Buffer
  return Filter:new(function(buffer)
    if type(buftypes) == "string" then
      return buffer.opt.buftype == buftypes
    else
      return vim.tbl_contains(buftypes, buffer.opt.buftype)
    end
  end)
end

---@return Filter
local function FilterFiletype(filetypes)
  ---@param buffer Buffer
  return Filter:new(function(buffer)
    if type(filetypes) == "string" then
      return buffer.opt.filetype == filetypes
    else
      return vim.tbl_contains(filetypes, buffer.opt.filetype)
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
