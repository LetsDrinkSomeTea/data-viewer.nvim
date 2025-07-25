local utils = require('data-viewer.utils')
local config = require('data-viewer.config')

---@param line string
---@param delim string
---@return string[]
local function parseLine(line, delim)
  local words = {}
  local quoted = false
  local currentValue = ''

  for i = 1, #line do
    local char = line:sub(i, i) -- Get the current character

    if char == '"' then
      quoted = not quoted
    elseif char == delim and not quoted then
      table.insert(words, currentValue)
      currentValue = ''
    else
      currentValue = currentValue .. char
    end
  end
  table.insert(words, currentValue)
  return words
end

---@param headerStr string
---@param delim string
---@return string[]
local function getHeaders(headerStr, delim)
  ---@type string[]
  return parseLine(headerStr, delim)
end

---@param csvLines string[]
---@param headers string[]
---@param delim string
---@return table<string, string>[]
local function getBody(csvLines, headers, delim)
  ---@type table<string, string>[]
  local body = {}
  for _, line in ipairs(csvLines) do
    local words = parseLine(line, delim)
    local lineObj = {}
    for idx, cell in ipairs(words) do
      lineObj[headers[idx]] = cell
    end
    table.insert(body, lineObj)
  end
  return body
end

---@param csvData string
---@param sheetName string
---@return table
local function parseSheet(csvData, sheetName)
  local lines = vim.split(csvData, '\n', { plain = true })

  -- Remove empty lines
  local filteredLines = {}
  for _, line in ipairs(lines) do
    if line and line:match('%S') then -- Line contains non-whitespace
      table.insert(filteredLines, line)
    end
  end

  if #filteredLines == 0 then
    return { headers = {}, bodyLines = {} }
  end

  local headers = getHeaders(filteredLines[1], ',')
  table.remove(filteredLines, 1)
  local bodyLines = getBody(filteredLines, headers, ',')

  -- Limit lines if configured
  if config.config.maxLineEachTable >= 0 and #bodyLines > config.config.maxLineEachTable then
    local limitedBodyLines = {}
    for i = 1, config.config.maxLineEachTable do
      table.insert(limitedBodyLines, bodyLines[i])
    end
    bodyLines = limitedBodyLines
  end

  return { headers = headers, bodyLines = bodyLines }
end

---@param filepath string|integer
local parse = function(filepath)
  if type(filepath) == 'number' then
    filepath = vim.api.nvim_buf_get_name(filepath)
  end

  -- Check if xlsx2csv is available
  local xlsx2csv_available = vim.fn.executable('xlsx2csv') == 1
  if not xlsx2csv_available then
    return 'xlsx2csv not found. Please install it with: pip install xlsx2csv'
  end

  -- Use xlsx2csv to convert all sheets to CSV format
  local cmd = string.format('xlsx2csv -a "%s"', vim.fn.shellescape(filepath))
  local handle = io.popen(cmd)
  if not handle then
    return 'Failed to execute xlsx2csv command'
  end

  local output = handle:read('*all')
  local success = handle:close()

  if not success then
    return 'xlsx2csv command failed'
  end

  -- Split output by sheet delimiter pattern (-------- {number} - {SheetName})
  local sheets = {}
  local currentSheet = nil
  local currentSheetName = nil

  for line in output:gmatch('[^\n]+') do
    local sheetNumber, sheetName = line:match('^%-%-%-%-%-%-%-%-+ (%d+) %- (.+)$')
    if sheetNumber and sheetName then
      -- Save previous sheet if it exists
      if currentSheet and currentSheetName then
        sheets[currentSheetName] = currentSheet
      end
      -- Start new sheet
      currentSheetName = sheetName
      currentSheet = {}
    elseif currentSheet then
      table.insert(currentSheet, line)
    end
  end

  -- Save the last sheet
  if currentSheet and currentSheetName then
    sheets[currentSheetName] = currentSheet
  end

  local tablesData = {}

  for sheetName, sheetLines in pairs(sheets) do
    if #sheetLines > 0 then
      local sheetData = table.concat(sheetLines, '\n')
      local parsedSheet = parseSheet(sheetData, sheetName)
      if #parsedSheet.headers > 0 then
        tablesData[sheetName] = parsedSheet
      end
    end
  end

  -- If no sheets were found with the delimiter method, try parsing as single sheet
  if vim.tbl_isempty(tablesData) then
    local singleSheetData = parseSheet(output, 'Sheet1')
    if #singleSheetData.headers > 0 then
      tablesData['Sheet1'] = singleSheetData
    end
  end

  if vim.tbl_isempty(tablesData) then
    return 'No data found in Excel file'
  end

  return tablesData
end

return parse
