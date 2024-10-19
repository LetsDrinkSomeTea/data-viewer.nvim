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
  for tableName, tableData in pairs(parsedData) do
    parsedData[tableName]["colMaxWidth"] = module.get_max_width(tableData.headers, tableData.bodyLines)

    
    local formatedLines = module.format_lines(tableData.headers, tableData.bodyLines, tableData["colMaxWidth"])
    parsedData[tableName]["formatedLines"] = utils.merge_array( { headerStr }, formatedLines)
    parsedData[tableName]["width"] = #formatedLines[1]
  end

  local first_bufnum = -1
  first_bufnum, parsedData = module.create_bufs(parsedData)

  M.parsed_data = parsedData
  M.header_info = headerInfo
  M.win_id = module.open_win(first_bufnum, opts.force_replace)

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

return M
