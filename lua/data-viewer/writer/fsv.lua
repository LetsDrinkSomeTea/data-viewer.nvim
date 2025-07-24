local utils = require("data-viewer.utils")

---@class CsvWriter
local M = {}

---@param headers string[]
---@param bodyLines table<string, string>[]
---@param filepath string
---@param delim string
---@return boolean success, string? error_message
M.write = function(headers, bodyLines, filepath, delim)
  if not filepath or filepath == "" then
    return false, "No filepath provided"
  end
  
  if type(filepath) == "number" then
    return false, "Cannot save to buffer, need file path"
  end

  local lines = {}
  
  -- Write header
  local header_line = table.concat(headers, delim)
  table.insert(lines, header_line)
  
  -- Write body lines
  for _, line in ipairs(bodyLines) do
    local values = {}
    for _, header in ipairs(headers) do
      local value = line[header] or ""
      -- Escape quotes in CSV values
      if delim == "," and string.find(value, '"') then
        value = string.gsub(value, '"', '""')
      end
      -- Quote values that contain the delimiter or quotes
      if delim == "," and (string.find(value, delim) or string.find(value, '"') or string.find(value, '\n')) then
        value = '"' .. value .. '"'
      end
      table.insert(values, value)
    end
    table.insert(lines, table.concat(values, delim))
  end
  
  -- Write to file
  local success, error_msg = pcall(function()
    vim.fn.writefile(lines, filepath)
  end)
  
  if not success then
    return false, "Failed to write file: " .. tostring(error_msg)
  end
  
  return true, nil
end

return M