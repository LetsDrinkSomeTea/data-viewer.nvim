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
M.adaptive_mode = true
M.autocmd_group = nil
M.last_buffer_width = nil

M.setup = function(args)
  config.setup(args) -- setup config
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

    local formatedLines = utils.merge_array(
      { headerStr },
      module.format_lines(tableData.headers, tableData.bodyLines, colWidthToUse)
    )

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
  
  vim.api.nvim_create_autocmd({"VimResized", "WinScrolled"}, {
    group = M.autocmd_group,
    callback = function()
      if utils.check_win_valid(M.win_id) then
        M.refresh_current_table()
      end
    end,
  })
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
