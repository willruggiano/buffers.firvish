local function s(n)
  return string.rep(" ", n)
end

local BufInfo = {}
BufInfo.__index = BufInfo

function BufInfo.new(info)
  return setmetatable({ bufinfo = info }, BufInfo)
end

function BufInfo:bufnr()
  return self.bufinfo.bufnr
end

function BufInfo:winid()
  return vim.fn.bufwinid(self.bufinfo.bufnr)
end

function BufInfo:modified()
  return self.bufinfo.changed == 1
end

function BufInfo:modifiable()
  return vim.bo[self:bufnr()].modifiable == true
end

function BufInfo:readonly()
  return vim.bo[self:bufnr()].readonly == true
end

function BufInfo:active()
  return self:winid() ~= -1
end

function BufInfo:hidden()
  return self.bufinfo.hidden == 1
end

function BufInfo:listed()
  return self.bufinfo.listed == 1
end

function BufInfo:named()
  return self.bufinfo.name ~= ""
end

function BufInfo:name()
  if self:named() then
    return string.format([["%s"]], self.bufinfo.name)
  else
    return [["[No Name]"]]
  end
end

function BufInfo:alternate()
  local alternate_file = vim.fn.expand "#"
  -- stylua: ignore start
  if
    string.match(self.bufinfo.name, alternate_file)
  or
    self.bufinfo.name == alternate_file
  then
    return true
  else
    return false
  end
  --stylua: ignore end
end

function BufInfo:current()
  local bufwinid = self:winid()
  for _, winid in ipairs(self.bufinfo.windows) do
    if bufwinid == winid then
      return true
    end
  end
  return false
end

function BufInfo:read_errors()
  -- TODO: need to look at source code for this one :/
  return false
end

function BufInfo:lnum()
  if self.bufinfo.lnum then
    return self.bufinfo.lnum
  else
    local winid = self:winid()
    if winid ~= -1 then
      return vim.fn.line(".", winid)
    end
  end
end

function BufInfo:last_used()
  return self.bufinfo.lastused
end

function BufInfo:last_used_date()
  return os.date("%c", self:last_used())
end

function BufInfo:channel()
  return vim.api.nvim_buf_get_option(self:bufnr(), "channel")
end

local TermInfo = {}
TermInfo.__index = TermInfo

function TermInfo.new(bufnr, channel)
  return setmetatable({ bufnr = bufnr, channel = channel }, TermInfo)
end

function TermInfo:running()
  -- TODO: This doesn't seem correct
  return vim.fn.jobpid(self.channel) ~= 0
end

function TermInfo:finished()
  -- TODO: Not sure how to get this one
  return false
end

function BufInfo:terminal()
  local channel = self:channel()
  if channel ~= 0 then
    return TermInfo.new(self:bufnr(), channel)
  else
    return false
  end
end

function BufInfo:p0()
  local n = string.len(tostring(self.bufinfo.bufnr))
  return s(3 - n) .. tostring(self.bufinfo.bufnr)
end

function BufInfo:p1()
  if self:listed() then
    return s(1)
  else
    -- an unlisted buffer
    return "u"
  end
end

function BufInfo:p2()
  if self:current() then
    -- the buffer in the current window
    return "%"
  end
  if self:alternate() then
    -- the alternate buffer
    return "#"
  end
  return s(1)
end

function BufInfo:p3()
  if self:active() then
    -- an active buffer: it is loaded and visible
    return "a"
  elseif self:hidden() then
    -- a hidden buffer: it is loaded, but currently not displayed in a window |hidden-buffer|
    return "h"
  end
  return s(0)
end

function BufInfo:p4()
  local term = self:terminal()
  if term then
    if term:running() then
      -- a terminal buffer with a running job
      return "R"
    elseif term:finished() then
      -- a terminal buffer with a finished job
      return "F"
    elseif term:none() then
      -- a terminal buffer without a job: `:terminal NONE`
      return "?"
    end
  elseif self:modifiable() == false then
    return "-"
  elseif self:readonly() then
    return "="
  end
  return s(1)
end

function BufInfo:p5()
  if self:modified() then
    return "+"
  elseif self:read_errors() then
    -- a buffer with read errors
    return "x"
  end
  return s(1)
end

function BufInfo:p6()
  return self:name()
end

function BufInfo:virt_text(opts)
  local text = {}
  if opts.last_used then
    table.insert(text, "last used: " .. self:last_used_date())
  end
  local lnum = self:lnum()
  if lnum then
    table.insert(text, 1, "line " .. lnum)
  end
  return { "(" .. table.concat(text, "; ") .. ")", "Comment" }
end

function BufInfo:repr()
  local format = table.concat {
    "%s", -- p0
    "%s", -- p1
    "%s", -- p2
    "%s", -- p3
    "%s", -- p4
    "%s", -- p5
    s(1),
    "%s", -- p6
  }

  -- stylua: ignore start
  return string.format(
    format,
    self:p0(),
    self:p1(),
    self:p2(),
    self:p3(),
    self:p4(),
    self:p5(),
    self:p6()
  )
  -- stylua: ignore end
end

return BufInfo
