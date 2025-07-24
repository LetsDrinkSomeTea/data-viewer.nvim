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
M.is_truncated = false

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

  -- Create buffers first to get window dimensions
  local first_bufnum = -1
  first_bufnum, parsedData = module.create_bufs(parsedData)

  M.parsed_data = parsedData
  M.header_info = headerInfo
  M.win_id = module.open_win({ first_bufnum, opts.force_replace })

  -- Get buffer width for intelligent column sizing
  local bufferWidth = vim.api.nvim_win_get_width(M.win_id)

  for tableName, tableData in pairs(parsedData) do
    parsedData[tableName]["colMaxWidth"] = module.get_max_width(tableData.headers, tableData.bodyLines)

    -- Apply buffer-aware column width calculation
    local colMaxWidth
    if config.config.view.maxColumnWidth > 0 then
      M.is_truncated = true
      colMaxWidth = module.get_buffer_aware_column_widths(tableData.headers, tableData.bodyLines, bufferWidth)
    else
      colMaxWidth = parsedData[tableName]["colMaxWidth"]
    end

    local formatedLines =
      utils.merge_array({ headerStr }, module.format_lines(tableData.headers, tableData.bodyLines, colMaxWidth))

    -- Update buffer content with properly sized columns
    vim.api.nvim_buf_set_option(tableData.bufnum, "modifiable", true)
    vim.api.nvim_buf_set_lines(tableData.bufnum, 0, -1, false, formatedLines)
    vim.api.nvim_buf_set_option(tableData.bufnum, "modifiable", false)
  end

  for _, header in ipairs(M.header_info) do
    local bufnum = parsedData[header.name].bufnum
    module.highlight_tables_header(bufnum, header)
  end

  if config.config.columnColorEnable then
    for _, tableData in pairs(parsedData) do
      module.highlight_header(tableData.bufnum, tableData.headers, tableData.colMaxWidth)
      module.highlight_rows(tableData.bufnum, tableData.headers, tableData.bodyLines, tableData.colMaxWidth)
    end
  end
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
  for _, tableData in pairs(M.parsed_data) do
    local buf = tableData.bufnum
    vim.api.nvim_buf_delete(buf, { force = true })
  end
  M.parsed_data = {}

  -- Close popup window
  if config.config.view.float and utils.check_win_valid(M.win_id) then
    vim.api.nvim_win_close(M.win_id, true)
  end
end

M.toggle_truncate = function()
  if not utils.check_win_valid(M.win_id) then
    return
  end

  M.is_truncated = not M.is_truncated

  -- Regenerate header string
  local headerStr, headerInfo = module.get_win_header_str(M.parsed_data)

  -- Get buffer width for intelligent column sizing
  local bufferWidth = vim.api.nvim_win_get_width(M.win_id)

  -- Regenerate formatted lines for all tables with new truncation setting
  for tableName, tableData in pairs(M.parsed_data) do
    local colMaxWidth
    if M.is_truncated and config.config.view.maxColumnWidth > 0 then
      -- Apply buffer-aware column width calculation
      colMaxWidth = module.get_buffer_aware_column_widths(tableData.headers, tableData.bodyLines, bufferWidth)
    else
      -- Use original column widths
      colMaxWidth = tableData.colMaxWidth
    end

    local formatedLines =
      utils.merge_array({ headerStr }, module.format_lines(tableData.headers, tableData.bodyLines, colMaxWidth))

    -- Update buffer content
    vim.api.nvim_buf_set_option(tableData.bufnum, "modifiable", true)
    vim.api.nvim_buf_set_lines(tableData.bufnum, 0, -1, false, formatedLines)
    vim.api.nvim_buf_set_option(tableData.bufnum, "modifiable", false)

    -- Reapply highlights if enabled
    if config.config.columnColorEnable then
      vim.api.nvim_buf_clear_namespace(tableData.bufnum, 0, 0, -1)
      module.highlight_header(tableData.bufnum, tableData.headers, colMaxWidth)
      module.highlight_rows(tableData.bufnum, tableData.headers, tableData.bodyLines, colMaxWidth)
    end
  end

  -- Update header info and re-highlight table headers
  M.header_info = headerInfo
  for _, header in ipairs(M.header_info) do
    local bufnum = M.parsed_data[header.name].bufnum
    module.highlight_tables_header(bufnum, header)
  end
end

return M
