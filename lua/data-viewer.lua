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

  -- Store original file info for saving
  M.original_filepath = filepath
  M.original_filetype = ft

  local headerStr, headerInfo = module.get_win_header_str(parsedData)
  for tableName, tableData in pairs(parsedData) do
    parsedData[tableName]["colMaxWidth"] = module.get_max_width(tableData.headers, tableData.bodyLines)
    parsedData[tableName]["formatedLines"] = utils.merge_array(
      { headerStr },
      module.format_lines(tableData.headers, tableData.bodyLines, tableData["colMaxWidth"])
    )
  end

  local first_bufnum = -1
  first_bufnum, parsedData = module.create_bufs(parsedData)

  M.parsed_data = parsedData
  M.header_info = headerInfo
  M.win_id = module.open_win { first_bufnum, opts.force_replace }

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
end

return M
