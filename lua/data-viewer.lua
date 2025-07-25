local module = require("data-viewer.module")
local parsers = require("data-viewer.parser.parsers")
local config = require("data-viewer.config")
local utils = require("data-viewer.utils")

---@class StartOptions
---@field silent? boolean
---@field args string
---@field force_replace? boolean
local StartOptions = {
  silent = false,
  args = "",
}

---@class DataViewer
local M = {}

M.cur_table = 1
M.win_id = -1
M.parsed_data = {}
M.header_info = {}
M.original_filepath = nil
M.original_filetype = nil
M.adaptive_mode = true
M.autocmd_group = nil
M.last_buffer_width = nil

M.setup = function(args)
  config.setup(args) -- setup config

  -- Define custom highlight group for delimiters (non-italic)
  vim.api.nvim_set_hl(0, "DataViewerDelimiter", {
    fg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("Comment")), "fg"),
    italic = false,
  })

  -- Define custom highlight group for focus table (defaults to Title)
  vim.api.nvim_set_hl(0, "DataViewerFocusTable", { link = "Title" })

  -- Define custom column highlight groups
  vim.api.nvim_set_hl(0, "DataViewerColumn1", { link = "String" })
  vim.api.nvim_set_hl(0, "DataViewerColumn2", { link = "Constant" })
  vim.api.nvim_set_hl(0, "DataViewerColumn3", { link = "Function" })
end

---@param opts? StartOptions
M.start = function(opts)
  if opts == nil or opts.args == nil then
    vim.print("Invalid Source")
    return
  end

  local filepath, ft = module.get_file_source_from_args(opts.args)
  if filepath == nil or ft == nil then
    vim.print("Usage: DataViewer [filetype] or DataViewer [filepath] [filetype]")
    return
  end

  ft = module.is_support_filetype(ft)
  if ft == "unsupport" then
    if not opts.silent then
      vim.print("Filetype unsupported")
    end
    return
  end

  local parsedData = parsers[ft](filepath)
  if type(parsedData) == "string" then
    vim.print(parsedData)
    return
  end

  -- Store original file info for saving
  M.original_filepath = filepath
  M.original_filetype = ft

  local headerStr, headerInfo = module.get_win_header_str(parsedData)
  M.adaptive_mode = config.config.view.adaptiveColumns

  -- Store original column widths for full-width mode
  for tableName, tableData in pairs(parsedData) do
    parsedData[tableName]["colMaxWidth"] = module.get_max_width(tableData.headers, tableData.bodyLines)
  end

  local first_bufnum = -1
  first_bufnum, parsedData = module.create_bufs_empty(parsedData)

  M.win_id = module.open_win({ first_bufnum, opts.force_replace })

  -- Format tables with proper width calculation from the start
  local bufferWidth = module.get_effective_width(M.win_id)
  M.last_buffer_width = bufferWidth
  for tableName, tableData in pairs(parsedData) do
    local colWidthToUse
    if M.adaptive_mode then
      colWidthToUse = module.get_adaptive_width(tableData.headers, tableData.bodyLines, bufferWidth)
    else
      colWidthToUse = tableData.colMaxWidth
    end

    local formatedLines =
      utils.merge_array({ headerStr }, module.format_lines(tableData.headers, tableData.bodyLines, colWidthToUse))

    vim.api.nvim_buf_set_option(tableData.bufnum, "modifiable", true)
    vim.api.nvim_buf_set_lines(tableData.bufnum, 0, -1, false, formatedLines)
    vim.api.nvim_buf_set_option(tableData.bufnum, "modifiable", false)

    -- Store the current column widths for highlighting
    parsedData[tableName]["currentColWidth"] = colWidthToUse
  end

  M.parsed_data = parsedData
  M.header_info = headerInfo

  for _, header in ipairs(M.header_info) do
    local bufnum = parsedData[header.name].bufnum
    module.highlight_tables_header(bufnum, header)
  end

  if config.config.columnColorEnable then
    for _, tableData in pairs(parsedData) do
      module.highlight_border_lines(tableData.bufnum)
      module.highlight_header(tableData.bufnum, tableData.headers, tableData.currentColWidth)
      module.highlight_rows(tableData.bufnum, tableData.headers, tableData.bodyLines, tableData.currentColWidth)
    end
  end

  -- Set up auto-formatting on window resize
  M.setup_auto_format()
end

M.setup_auto_format = function()
  if M.autocmd_group then
    vim.api.nvim_del_augroup_by_id(M.autocmd_group)
  end

  M.autocmd_group = vim.api.nvim_create_augroup("DataViewerAutoFormat", { clear = true })

  vim.api.nvim_create_autocmd(
    { "VimResized", "WinScrolled", "BufEnter", "BufLeave", "BufWinEnter", "BufWinLeave", "FocusGained", "FocusLost" },
    {
      group = M.autocmd_group,
      callback = function()
        if utils.check_win_valid(M.win_id) then
          M.refresh_current_table()
        end
      end,
    }
  )
end

M.next_table = function()
  if not utils.check_win_valid(M.win_id) then
    return
  end
  local old_buf = M.parsed_data[M.header_info[M.cur_table].name].bufnum
  M.cur_table = M.cur_table == #M.header_info and 1 or M.cur_table + 1
  local buf = M.parsed_data[M.header_info[M.cur_table].name].bufnum
  module.switch_buffer(M.win_id, old_buf, buf)
end

M.prev_table = function()
  if not utils.check_win_valid(M.win_id) then
    return
  end
  local old_buf = M.parsed_data[M.header_info[M.cur_table].name].bufnum
  M.cur_table = M.cur_table - 1 == 0 and #M.header_info or M.cur_table - 1
  local buf = M.parsed_data[M.header_info[M.cur_table].name].bufnum
  module.switch_buffer(M.win_id, old_buf, buf)
end

M.close_tables = function()
  -- Clean up autocmd group
  if M.autocmd_group then
    vim.api.nvim_del_augroup_by_id(M.autocmd_group)
    M.autocmd_group = nil
  end

  for _, tableData in pairs(M.parsed_data) do
    local buf = tableData.bufnum
    vim.api.nvim_buf_delete(buf, { force = true })
  end
  M.parsed_data = {}
  M.last_buffer_width = nil

  -- Close popup window
  if config.config.view.float and utils.check_win_valid(M.win_id) then
    vim.api.nvim_win_close(M.win_id, true)
  end
end

M.save = function()
  if not M.original_filepath or not M.original_filetype then
    vim.print("No original file information available")
    return
  end
  
  if M.original_filetype ~= "csv" and M.original_filetype ~= "tsv" then
    vim.print("Saving is only supported for CSV and TSV files currently")
    return
  end
  
  local current_table_name = M.header_info[M.cur_table].name
  local current_buf = M.parsed_data[current_table_name].bufnum
  
  if not vim.api.nvim_buf_is_valid(current_buf) then
    vim.print("Current buffer is not valid")
    return
  end
  
  -- Get current buffer content
  local lines = vim.api.nvim_buf_get_lines(current_buf, 0, -1, false)
  
  -- Parse the formatted table back to data structure
  local table_parser = require("data-viewer.parser.table_parser")
  local headers, body_lines, error_msg = table_parser.parse_formatted_table(lines)
  
  if error_msg then
    vim.print("Error parsing table: " .. error_msg)
    return
  end
  
  if not headers or #headers == 0 then
    vim.print("No headers found in table")
    return
  end
  
  -- Validate that the structure matches the original
  local original_table_name = M.header_info[M.cur_table].name
  local original_headers = M.parsed_data[original_table_name].headers
  
  if #headers ~= #original_headers then
    vim.print("Error: Number of columns changed. Expected " .. #original_headers .. " columns, found " .. #headers)
    return
  end
  
  -- Check if column names match (order matters for CSV/TSV)
  for i, header in ipairs(headers) do
    if header ~= original_headers[i] then
      vim.print("Warning: Column '" .. original_headers[i] .. "' changed to '" .. header .. "' in position " .. i)
    end
  end
  
  -- Determine delimiter
  local delim = M.original_filetype == "csv" and "," or "\t"
  
  -- Write back to file
  local fsv_writer = require("data-viewer.writer.fsv")
  local success, write_error = fsv_writer.write(headers, body_lines or {}, M.original_filepath, delim)
  
  if not success then
    vim.print("Error saving file: " .. (write_error or "unknown error"))
    return
  end
  
  vim.print("File saved successfully")

 M.toggle_adaptive = function()
  if not utils.check_win_valid(M.win_id) then
    return
  end

  M.adaptive_mode = not M.adaptive_mode
  -- Force refresh by clearing the cached width when toggling mode
  M.last_buffer_width = nil
  M.refresh_current_table()
end

M.refresh_current_table = function()
  if not utils.check_win_valid(M.win_id) then
    return
  end

  -- Get buffer width
  local bufferWidth = module.get_effective_width(M.win_id)

  -- Skip if buffer width hasn't changed and we're in adaptive mode
  if M.adaptive_mode and M.last_buffer_width == bufferWidth then
    return
  end

  M.last_buffer_width = bufferWidth
  local headerStr, _ = module.get_win_header_str(M.parsed_data)

  -- Refresh all tables to ensure consistency
  for tableName, tableData in pairs(M.parsed_data) do
    -- Calculate column widths based on mode
    local colMaxWidth
    if M.adaptive_mode then
      colMaxWidth = module.get_adaptive_width(tableData.headers, tableData.bodyLines, bufferWidth)
    else
      colMaxWidth = tableData.colMaxWidth
    end

    -- Store updated column widths
    M.parsed_data[tableName]["currentColWidth"] = colMaxWidth

    -- Reformat lines
    local formatedLines =
      utils.merge_array({ headerStr }, module.format_lines(tableData.headers, tableData.bodyLines, colMaxWidth))

    -- Update buffer content
    vim.api.nvim_buf_set_option(tableData.bufnum, "modifiable", true)
    vim.api.nvim_buf_set_lines(tableData.bufnum, 0, -1, false, formatedLines)
    vim.api.nvim_buf_set_option(tableData.bufnum, "modifiable", false)

    -- Refresh highlighting
    if config.config.columnColorEnable then
      vim.api.nvim_buf_clear_namespace(tableData.bufnum, 0, 0, -1)
      -- Find the header info for this table
      local headerInfo = nil
      for _, header in ipairs(M.header_info) do
        if header.name == tableName then
          headerInfo = header
          break
        end
      end
      if headerInfo then
        module.highlight_tables_header(tableData.bufnum, headerInfo)
      end
      module.highlight_border_lines(tableData.bufnum)
      module.highlight_header(tableData.bufnum, tableData.headers, colMaxWidth)
      module.highlight_rows(tableData.bufnum, tableData.headers, tableData.bodyLines, colMaxWidth)
    end
  end

  -- Set window options
  vim.api.nvim_win_set_option(M.win_id, "wrap", false)
end

M.expand_cell = function()
  if not utils.check_win_valid(M.win_id) then
    return
  end

  local currentTableName = M.header_info[M.cur_table].name
  local tableData = M.parsed_data[currentTableName]

  -- Get cursor position
  local cursor = vim.api.nvim_win_get_cursor(M.win_id)
  local row = cursor[1]
  local col = cursor[2]

  if row <= 4 then
    return
  end

  -- Calculate which data row and column we're in
  local dataRow = row - 4 -- Adjust for header rows
  if dataRow > #tableData.bodyLines then
    return
  end

  -- Find which column the cursor is in
  local line = vim.api.nvim_buf_get_lines(tableData.bufnum, row - 1, row, false)[1]
  if not line then
    return
  end

  local columnIndex = module.get_column_at_position(line, col, tableData.headers)
  if not columnIndex then
    return
  end

  local columnName = tableData.headers[columnIndex]
  local cellContent = tableData.bodyLines[dataRow][columnName]

  -- Show cell content in floating window
  module.show_cell_popup(cellContent, columnName)
end

return M
