local TermInfo = {}
TermInfo.__index = TermInfo

function TermInfo.new(bufnr, channel)
  return setmetatable({ bufnr = bufnr, channel = channel }, TermInfo)
end

function TermInfo:running()
  local ok, jobpid = pcall(vim.fn.jobpid, self.channel)
  return ok and jobpid ~= 0
end

function TermInfo:finished()
  -- TODO: Not sure how to get this one
  return false
end

function TermInfo:none()
  if pcall(vim.fn.jobpid, self.channel) then
    return false
  else
    return true
  end
end

return TermInfo
