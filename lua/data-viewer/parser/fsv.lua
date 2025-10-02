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

---@param fileType string
---@param delim string
local function createParse(fileType, delim)
  ---@param filepath string
  ---@param opts? {offset?: number, limit?: number}
  return function(filepath, opts)
    opts = opts or {}
    local offset = opts.offset or 0
    local limit = opts.limit or config.config.pageSize
    
    -- Read first line for headers
    local allLines = utils.read_file(filepath)
    if #allLines == 0 then
      return { [fileType] = { headers = {}, bodyLines = {}, totalDataLines = 0, currentPage = 1, pageSize = limit } }
    end
    
    local headers = getHeaders(allLines[1], delim)
    
    -- Get total data lines (excluding header)
    local totalDataLines = #allLines - 1
    
    -- Read data lines with offset and limit
    local dataLines = {}
    local startIdx = offset + 2 -- +2 because we skip header (index 1) and apply offset
    local endIdx = startIdx + limit - 1 -- Read exactly 'limit' lines starting from startIdx
    
    for i = startIdx, math.min(endIdx, #allLines) do
      if allLines[i] then
        table.insert(dataLines, allLines[i])
      end
    end
    
    local bodyLines = getBody(dataLines, headers, delim)
    local out = {}
    out[fileType] = { 
      headers = headers, 
      bodyLines = bodyLines,
      totalDataLines = totalDataLines,
      currentPage = math.floor(offset / limit) + 1,
      pageSize = limit
    }
    return out
  end
end

return createParse
