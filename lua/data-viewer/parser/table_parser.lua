local utils = require("data-viewer.utils")

---@class TableParser
local M = {}

---@param lines string[]
---@return string[], table<string, string>[]?, string?
M.parse_formatted_table = function(lines)
  if not lines or #lines < 4 then
    return {}, nil, "Invalid table format: too few lines"
  end
  
  -- Skip the header info line (first line with table names)
  local start_line = 1
  for i, line in ipairs(lines) do
    if string.find(line, "┌") then
      start_line = i
      break
    end
  end
  
  if start_line >= #lines then
    return {}, nil, "Could not find table start"
  end
  
  -- Find the header line (between ┌ and ├)
  local header_line_idx = nil
  for i = start_line + 1, #lines do
    local line = lines[i]
    if line and not string.find(line, "┌") and not string.find(line, "├") and not string.find(line, "└") and string.find(line, "|") then
      header_line_idx = i
      break
    end
  end
  
  if not header_line_idx then
    return {}, nil, "Could not find header line"
  end
  
  -- Parse header line to extract column names and positions
  local header_line = lines[header_line_idx]
  local headers = {}
  local col_positions = {}
  
  -- Split by | and extract column names
  local parts = {}
  for part in string.gmatch(header_line, "[^|]+") do
    table.insert(parts, part)
  end
  
  for _, part in ipairs(parts) do
    local trimmed = string.match(part, "^%s*(.-)%s*$") -- trim whitespace
    if trimmed and trimmed ~= "" then
      table.insert(headers, trimmed)
    end
  end
  
  if #headers == 0 then
    return {}, nil, "No headers found"
  end
  
  -- Find data lines (after ├ and before └)
  local data_start = nil
  local data_end = nil
  
  for i = header_line_idx + 1, #lines do
    if string.find(lines[i], "├") then
      data_start = i + 1
      break
    end
  end
  
  for i = #lines, 1, -1 do
    if string.find(lines[i], "└") then
      data_end = i - 1
      break
    end
  end
  
  if not data_start or not data_end or data_start > data_end then
    return headers, {}, nil -- Valid headers but no data
  end
  
  -- Parse data lines
  local body_lines = {}
  for i = data_start, data_end do
    local line = lines[i]
    if line and string.find(line, "|") and not string.find(line, "─") then
      local parts = {}
      for part in string.gmatch(line, "[^|]+") do
        table.insert(parts, part)
      end
      
      if #parts >= #headers then
        local row = {}
        for j, header in ipairs(headers) do
          local value = parts[j]
          if value then
            value = string.match(value, "^%s*(.-)%s*$") -- trim whitespace
            row[header] = value or ""
          else
            row[header] = ""
          end
        end
        table.insert(body_lines, row)
      end
    end
  end
  
  return headers, body_lines, nil
end

return M