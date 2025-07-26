local config = require('data-viewer.config')

---@class Utils
local M = {}

---@param array1 any[]
---@param array2 any[]
---@return any[]
M.merge_array = function(array1, array2)
  local ret_array = {}
  for _, val in ipairs(array1) do
    table.insert(ret_array, val)
  end
  for _, val in ipairs(array2) do
    table.insert(ret_array, val)
  end
  return ret_array
end

---@generic T
---@param array T[]
---@param num number
---@return T[]
M.slice_array = function(array, num)
  if num <= 0 then
    return array
  end

  local ret = {}
  for i, val in ipairs(array) do
    if i <= num then
      table.insert(ret, val)
    end
  end
  return ret
end

---@generic T
---@param array T[]
---@param offset number
---@param limit number
---@return T[]
M.slice_array_with_offset = function(array, offset, limit)
  if limit <= 0 then
    return array
  end

  local ret = {}
  local startIdx = offset + 1 -- Lua arrays are 1-indexed
  local endIdx = offset + limit
  
  for i = startIdx, math.min(endIdx, #array) do
    table.insert(ret, array[i])
  end
  return ret
end

---@param str string
---@return number
M.getStringDisplayLength = function(str)
  return vim.fn.strdisplaywidth(str)
end

---@param str string
---@return number
M.getStringByteLength = function(str)
  return vim.fn.strlen(str)
end

---@param str string
---@return table {stringDisplayLength: number, stringByteLength: number}
M.getStringLength = function(str)
  return { M.getStringDisplayLength(str), M.getStringByteLength(str) }
end

---@param str string
---@param sep string
---@return string[]
M.split_string = function(str, sep)
  local ret = {}
  local pattern = '[^' .. sep .. ']+'

  for segment in string.gmatch(str, pattern) do
    table.insert(ret, segment)
  end
  return ret
end

---@param file string | number
---@param offset? number
---@param limit? number
---@return string[]
M.read_file = function(file, offset, limit)
  local maxLines = limit or config.config.maxLineEachTable
  local startLine = offset or 0
  
  if type(file) == 'number' then
    -- buf_number
    local lines = vim.api.nvim_buf_get_lines(file, 0, -1, false)
    return M.slice_array_with_offset(lines, startLine, maxLines)
  elseif type(file) == 'string' then
    -- file path
    local lines = vim.fn.readfile(file)
    return M.slice_array_with_offset(lines, startLine, maxLines)
  else
    return {}
  end
end

---@param file string | number
---@return number
M.get_total_lines = function(file)
  if type(file) == 'number' then
    -- buf_number
    local lines = vim.api.nvim_buf_get_lines(file, 0, -1, false)
    return #lines
  elseif type(file) == 'string' then
    -- file path
    local lines = vim.fn.readfile(file)
    return #lines
  else
    return 0
  end
end

---@param win_id number
---@return boolean
M.check_win_valid = function(win_id)
  if vim.api.nvim_win_is_valid(win_id) and vim.api.nvim_get_current_win() == win_id then
    return true
  else
    return false
  end
end

---@param str string
---@param maxWidth number
---@return string
M.truncateString = function(str, maxWidth)
  if maxWidth <= 0 then
    return ''
  end

  if vim.fn.strdisplaywidth(str) <= maxWidth then
    return str
  end

  if maxWidth == 1 then
    return '…'
  end

  -- Binary search to find the correct truncation point
  local left, right = 1, #str
  local bestEnd = 1

  while left <= right do
    local mid = math.floor((left + right) / 2)
    local substr = string.sub(str, 1, mid)
    local width = vim.fn.strdisplaywidth(substr)

    if width <= maxWidth - 1 then -- Leave space for ellipsis
      bestEnd = mid
      left = mid + 1
    else
      right = mid - 1
    end
  end

  return string.sub(str, 1, bestEnd) .. '…'
end

return M
