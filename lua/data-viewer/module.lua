local parsers = require("data-viewer.parser.parsers")
local utils = require("data-viewer.utils")
local config = require("data-viewer.config")

local KEYMAP_OPTS = { noremap = true, silent = true }

---@class CustomModule
local M = {}

---@param filetype string
---@return string | "'unsupport'"
M.is_support_filetype = function(filetype)
  for parserName, _ in pairs(parsers) do
    if parserName == filetype then
      return filetype
    end
  end
  return "unsupport"
end

---@param header string[]
---@param lines table<string, string>[]
---@return table<string, number>
M.get_max_width = function(header, lines)
  local colMaxWidth = {}
  for _, colName in ipairs(header) do
    colMaxWidth[colName] = utils.getStringDisplayLength(colName)
  end

  for _, line in ipairs(lines) do
    for _, colName in ipairs(header) do
      colMaxWidth[colName] = math.max(utils.getStringDisplayLength(line[colName]), colMaxWidth[colName])
    end
  end

  return colMaxWidth
end

---@param header string[]
---@param lines table<string, string>[]
---@param bufferWidth number
---@return table<string, number>
M.get_adaptive_width = function(header, lines, bufferWidth)
  local colMaxWidth = M.get_max_width(header, lines)
  local numCols = #header

  -- Calculate total width with borders (|col1|col2|col3|)
  local borderWidth = numCols + 1
  local availableWidth = bufferWidth - borderWidth

  if availableWidth <= 0 then
    return colMaxWidth
  end

  -- Calculate initial distribution
  local maxWidthPerCol = math.floor(availableWidth / numCols)
  local totalActualWidth = 0
  local narrowCols = {}
  local wideCols = {}

  -- Categorize columns
  for _, colName in ipairs(header) do
    if colMaxWidth[colName] <= maxWidthPerCol then
      table.insert(narrowCols, colName)
      totalActualWidth = totalActualWidth + colMaxWidth[colName]
    else
      table.insert(wideCols, colName)
    end
  end

  -- Redistribute unused space from narrow columns to wide columns
  local extraSpace = availableWidth - totalActualWidth - (#wideCols * maxWidthPerCol)
  local extraSpacePerWideCol = #wideCols > 0 and math.floor(extraSpace / #wideCols) or 0

  local adaptiveWidth = {}
  for _, colName in ipairs(header) do
    if vim.tbl_contains(narrowCols, colName) then
      adaptiveWidth[colName] = colMaxWidth[colName]
    else
      adaptiveWidth[colName] = maxWidthPerCol + extraSpacePerWideCol
    end
  end

  return adaptiveWidth
end

---@param header string[]
---@param colMaxWidth table<string, number>
---@return string[]
M.format_header = function(header, colMaxWidth)
  local formatedHeader = ""
  for _, colName in ipairs(header) do
    local maxWidth = colMaxWidth[colName]
    local truncatedColName = colName

    -- Truncate column name if it's too long
    truncatedColName = utils.truncateString(colName, maxWidth)

    local spaceNum = maxWidth - utils.getStringDisplayLength(truncatedColName)
    local spaceStr = string.rep(" ", math.floor(spaceNum / 2))
    formatedHeader = formatedHeader .. "|" .. spaceStr .. truncatedColName .. spaceStr .. string.rep(" ", spaceNum % 2)
  end
  formatedHeader = formatedHeader .. "|"

  local tableBorder = string.rep("─", utils.getStringDisplayLength(formatedHeader) - 2)
  local firstLine = "┌" .. tableBorder .. "┐"
  local lastLine = "├" .. tableBorder .. "┤"
  return { firstLine, formatedHeader, lastLine }
end

---@param bodyLines table<string, string>[]
---@param header string[]
---@param colMaxWidth table<string, number>
---@return string[]
M.format_body = function(bodyLines, header, colMaxWidth)
  local formatedLines = {}
  for _, line in ipairs(bodyLines) do
    local formatedLine = ""
    for _, colName in ipairs(header) do
      local cellContent = line[colName] or ""
      local maxWidth = colMaxWidth[colName]
      local truncatedContent = cellContent

      -- Truncate cell content if it's too long
      truncatedContent = utils.truncateString(cellContent, maxWidth)

      local spaceNum = maxWidth - utils.getStringDisplayLength(truncatedContent)
      local spaceStr = string.rep(" ", spaceNum)
      formatedLine = formatedLine .. "|" .. truncatedContent .. spaceStr
    end
    formatedLine = formatedLine .. "|"
    table.insert(formatedLines, formatedLine)
  end

  table.insert(formatedLines, "└" .. string.rep("─", utils.getStringDisplayLength(formatedLines[1]) - 2) .. "┘")
  return formatedLines
end

---@param header string[]
---@param lines table<string, string>[]
---@param colMaxWidth table<string, number>
M.format_lines = function(header, lines, colMaxWidth)
  local formatedHeader = M.format_header(header, colMaxWidth)
  local formatedBody = M.format_body(lines, header, colMaxWidth)
  return utils.merge_array(formatedHeader, formatedBody)
end

---@param tablesData table<string, any>
---@return string, table<string, string | number>[]
M.get_win_header_str = function(tablesData)
  local pos = {}
  local header = "|"
  local index = 1
  for tableName, _ in pairs(tablesData) do
    table.insert(pos, { name = tableName, startPos = #header + 1 })
    header = header .. " " .. tableName .. " |"
    index = index + 1
  end
  return header, pos
end

---@param tablesData table<string, any>
---@return number, table<string, any>
M.create_bufs = function(tablesData)
  local first_bufnum = -1
  for tableName, tableData in pairs(tablesData) do
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, tableData.formatedLines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    vim.api.nvim_buf_set_name(buf, "DataViwer-" .. tableName)
    vim.api.nvim_buf_set_keymap(buf, "n", config.config.keymap.next_table, ":DataViewerNextTable<CR>", KEYMAP_OPTS)
    vim.api.nvim_buf_set_keymap(buf, "n", config.config.keymap.prev_table, ":DataViewerPrevTable<CR>", KEYMAP_OPTS)
    vim.api.nvim_buf_set_keymap(buf, "n", config.config.keymap.quit, ":DataViewerClose<CR>", KEYMAP_OPTS)
    vim.api.nvim_buf_set_keymap(
      buf,
      "n",
      config.config.keymap.toggle_adaptive,
      ":DataViewerToggleAdaptive<CR>",
      KEYMAP_OPTS
    )
    vim.api.nvim_buf_set_keymap(buf, "n", config.config.keymap.expand_cell, ":DataViewerExpandCell<CR>", KEYMAP_OPTS)
    tablesData[tableName]["bufnum"] = buf
    if first_bufnum == -1 then
      first_bufnum = buf
    end
  end
  return first_bufnum, tablesData
end

---@param tablesData table<string, any>
---@return number, table<string, any>
M.create_bufs_empty = function(tablesData)
  local first_bufnum = -1
  for tableName, tableData in pairs(tablesData) do
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)

    -- Check if buffer with this name exists and delete it
    local buf_name = "DataViwer-" .. tableName
    local existing_buf = vim.fn.bufnr(buf_name)
    if existing_buf ~= -1 then
      vim.api.nvim_buf_delete(existing_buf, { force = true })
    end

    vim.api.nvim_buf_set_name(buf, buf_name)
    vim.api.nvim_buf_set_keymap(buf, "n", config.config.keymap.next_table, ":DataViewerNextTable<CR>", KEYMAP_OPTS)
    vim.api.nvim_buf_set_keymap(buf, "n", config.config.keymap.prev_table, ":DataViewerPrevTable<CR>", KEYMAP_OPTS)
    vim.api.nvim_buf_set_keymap(buf, "n", config.config.keymap.quit, ":DataViewerClose<CR>", KEYMAP_OPTS)
    vim.api.nvim_buf_set_keymap(
      buf,
      "n",
      config.config.keymap.toggle_adaptive,
      ":DataViewerToggleAdaptive<CR>",
      KEYMAP_OPTS
    )
    vim.api.nvim_buf_set_keymap(buf, "n", config.config.keymap.expand_cell, ":DataViewerExpandCell<CR>", KEYMAP_OPTS)
    tablesData[tableName]["bufnum"] = buf
    if first_bufnum == -1 then
      first_bufnum = buf
    end
  end
  return first_bufnum, tablesData
end

---@tparam buf_id number
---@tparam force_replace boolean
---@return number
M.open_win = function(opts)
  local buf_id = opts[1]
  local force_replace = opts[2]

  if not config.config.view.float or force_replace then
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_buf_set_option(buf_id, "buflisted", true)
    vim.api.nvim_set_current_buf(buf_id)
    return win
  end

  local screenHeight = vim.opt.lines:get()
  local screenWidth = vim.opt.columns:get()
  local height = math.max(1, math.floor(screenHeight * config.config.view.height))
  local width = math.max(1, math.floor(screenWidth * config.config.view.width))
  local win = vim.api.nvim_open_win(buf_id, true, {
    relative = config.config.view.relative and "win" or "editor",
    width = width,
    height = height,
    row = math.max(1, math.floor((screenHeight - height) / 2)),
    col = math.max(1, math.floor((screenWidth - width) / 2)),
    style = "minimal",
    zindex = config.config.view.zindex,
    title = "Data Viewer",
    title_pos = "center",
    border = "single",
  })

  -- Set the window options
  vim.api.nvim_win_set_option(win, "wrap", not config.config.view.adaptiveColumns)
  vim.api.nvim_win_set_option(win, "number", false)
  vim.api.nvim_win_set_option(win, "cursorline", false)
  return win
end

---@param bufnum number
---@param headers string[]
---@param colMaxWidth table<string, number>
M.highlight_header = function(bufnum, headers, colMaxWidth)
  local curPos = 0 -- Start from beginning of line
  for j, colName in ipairs(headers) do
    -- Highlight delimiter
    vim.api.nvim_buf_add_highlight(bufnum, 0, config.config.delimiterHighlight, 2, curPos, curPos + 1)

    local hlStart = curPos + 1 -- skip delimiter
    local hlEnd = hlStart + colMaxWidth[colName]

    -- Highlight column content
    vim.api.nvim_buf_add_highlight(
      bufnum,
      0,
      config.config.columnColorRoulette[(j % #config.config.columnColorRoulette) + 1],
      2,
      hlStart,
      hlEnd
    )
    curPos = hlEnd -- Move to start of next column
  end

  -- Highlight final delimiter
  vim.api.nvim_buf_add_highlight(bufnum, 0, config.config.delimiterHighlight, 2, curPos, curPos + 1)
end

---@param bufnum number
---@param headers string[]
---@param bodyLines table<string, string>[]
---@param colMaxWidth table<string, number>
M.highlight_rows = function(bufnum, headers, bodyLines, colMaxWidth)
  for i = 1, #bodyLines do
    local curPos = 0 -- Start from beginning of line
    for j, colName in ipairs(headers) do
      -- Highlight delimiter
      vim.api.nvim_buf_add_highlight(bufnum, 0, config.config.delimiterHighlight, i + 3, curPos, curPos + 1)

      local hlStart = curPos + 1 -- skip delimiter
      local hlEnd = hlStart + colMaxWidth[colName]

      -- Highlight column content
      vim.api.nvim_buf_add_highlight(
        bufnum,
        0,
        config.config.columnColorRoulette[(j % #config.config.columnColorRoulette) + 1],
        i + 3,
        hlStart,
        hlEnd
      )
      curPos = hlEnd -- Move to start of next column
    end

    -- Highlight final delimiter
    vim.api.nvim_buf_add_highlight(bufnum, 0, config.config.delimiterHighlight, i + 3, curPos, curPos + 1)
  end
end

---@param bufnum number
---@param info table<string, string | number>
M.highlight_tables_header = function(bufnum, info)
  vim.api.nvim_buf_add_highlight(
    bufnum,
    0,
    config.config.focusTableHighlight,
    0,
    info.startPos,
    info.startPos + #info.name
  )
end

---@param bufnum number
M.highlight_border_lines = function(bufnum)
  -- Get total line count
  local line_count = vim.api.nvim_buf_line_count(bufnum)

  -- Highlight the top border line (row 1)
  local line1 = vim.api.nvim_buf_get_lines(bufnum, 1, 2, false)[1]
  if line1 then
    vim.api.nvim_buf_add_highlight(bufnum, 0, config.config.delimiterHighlight, 1, 0, #line1)
  end

  -- Highlight the bottom header border line (row 3)
  local line3 = vim.api.nvim_buf_get_lines(bufnum, 3, 4, false)[1]
  if line3 then
    vim.api.nvim_buf_add_highlight(bufnum, 0, config.config.delimiterHighlight, 3, 0, #line3)
  end

  -- Highlight the bottom table border line (last line)
  local last_line = vim.api.nvim_buf_get_lines(bufnum, line_count - 1, line_count, false)[1]
  if
    last_line and (last_line:match("^[└┴┘─]+$") or last_line:match("^[┌┬┐─├┼┤└┴┘│]+$"))
  then
    vim.api.nvim_buf_add_highlight(bufnum, 0, config.config.delimiterHighlight, line_count - 1, 0, #last_line)
  end
end

---@param args string
---@return string | number | nil, string | nil
M.get_file_source_from_args = function(args)
  local args_array = utils.split_string(args, " ")
  if #args_array > 2 then
    return nil, nil
  elseif #args_array == 2 then
    local filepath = args_array[1]
    local ft = string.lower(args_array[2])
    return filepath, ft
  elseif #args_array == 1 then
    local filepath = vim.api.nvim_get_current_buf()
    local ft = string.lower(args_array[1])
    return filepath, ft
  else
    local filepath = vim.api.nvim_get_current_buf()
    local ft = vim.api.nvim_buf_get_option(filepath, "filetype")
    return filepath, ft
  end
end

---@param win_id number
---@param old_buf number
---@param new_buf number
M.switch_buffer = function(win_id, old_buf, new_buf)
  if not config.config.view.float then
    vim.api.nvim_buf_set_option(old_buf, "buflisted", false)
    vim.api.nvim_buf_set_option(new_buf, "buflisted", true)
  end
  vim.api.nvim_win_set_buf(win_id, new_buf)
end

---@param win_id number
---@return number
M.get_effective_width = function(win_id)
  local winWidth = vim.api.nvim_win_get_width(win_id)
  local buf = vim.api.nvim_win_get_buf(win_id)

  -- Account for line numbers
  local numberWidth = 0
  if vim.api.nvim_win_get_option(win_id, "number") or vim.api.nvim_win_get_option(win_id, "relativenumber") then
    local lineCount = vim.api.nvim_buf_line_count(buf)
    numberWidth = math.max(2, string.len(tostring(lineCount))) + 1 -- +1 for space
  end

  -- Account for sign column
  local signWidth = 0
  local signcolumn = vim.api.nvim_win_get_option(win_id, "signcolumn")
  if signcolumn == "yes" then
    signWidth = 2
  elseif signcolumn == "auto" then
    -- This is harder to calculate precisely, assume 0 for now
    signWidth = 0
  end

  -- Account for fold column
  local foldWidth = vim.api.nvim_win_get_option(win_id, "foldcolumn")

  return winWidth - numberWidth - signWidth - foldWidth
end

---@param line string
---@param col number
---@param headers string[]
---@return number | nil
M.get_column_at_position = function(line, col, headers)
  -- Find all pipe positions
  local pipePositions = {}
  local pos = 0

  while true do
    pos = line:find("|", pos + 1)
    if not pos then
      break
    end
    table.insert(pipePositions, pos)
  end

  if #pipePositions < 2 then
    return nil
  end

  -- Check which column the cursor is in
  for i = 1, #pipePositions - 1 do
    local startPos = pipePositions[i]
    local endPos = pipePositions[i + 1]

    if col >= startPos and col < endPos then
      return i
    end
  end

  return nil
end

---@param content string
---@param columnName string
M.show_cell_popup = function(content, columnName)
  -- Convert content to string if it's not already
  content = tostring(content)

  -- Create a scratch buffer for the popup
  local buf = vim.api.nvim_create_buf(false, true)

  -- Split content into lines if it's very long
  local lines = {}
  local width = 60

  if #content <= width then
    table.insert(lines, content)
  else
    -- Word wrap long content
    local words = vim.split(content, " ")
    local currentLine = ""

    for _, word in ipairs(words) do
      if #currentLine + #word + 1 <= width then
        currentLine = currentLine == "" and word or currentLine .. " " .. word
      else
        if currentLine ~= "" then
          table.insert(lines, currentLine)
        end
        currentLine = word
      end
    end

    if currentLine ~= "" then
      table.insert(lines, currentLine)
    end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  -- Calculate popup size
  local height = math.min(#lines + 2, 10)

  -- Create floating window
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "cursor",
    width = width,
    height = height,
    row = 1,
    col = 0,
    style = "minimal",
    border = "rounded",
    title = columnName,
    title_pos = "center",
  })

  -- Close on cursor move
  vim.api.nvim_create_autocmd("CursorMoved", {
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
      return true -- Remove the autocmd after first trigger
    end,
    once = true,
  })
end

return M
