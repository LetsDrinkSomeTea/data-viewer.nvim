---@class ViewConfig
---@field width number
---@field height number
---@field zindex number
---@field adaptiveColumns boolean
local ViewConfig = {
  float = false, -- use float window or not
  width = 0.8,
  height = 0.8,
  zindex = 50,
  relative = true,
  adaptiveColumns = true, -- default to truncated adaptive display
}

---@class KeymapConfig
---@field quit string
---@field next_table string
---@field prev_table string
---@field toggle_adaptive string
---@field expand_cell string
local KeymapConfig = {
  quit = 'q',
  next_table = '<C-n>',
  prev_table = '<C-p>',
  toggle_adaptive = '<C-t>',
  expand_cell = '<C-e>',
}

---@class Config
---@field columnColorEnable boolean
---@field maxLineEachTable number
---@field columnColorRoulette string[]
---@field autoDisplayDsv boolean
---@field autoDisplaySqlite boolean
---@field view ViewConfig
local DefaultConfig = {
  autoDisplayDsv = true,
  autoDisplaySqlite = true,
  showSqlSequenceTable = false,
  maxLineEachTable = 100,
  columnColorEnable = true,
  columnColorRoulette = { 'DataViewerColumn1', 'DataViewerColumn2', 'DataViewerColumn3' },
  delimiterHighlight = 'DataViewerDelimiter',
  focusTableHighlight = 'DataViewerFocusTable',
  view = ViewConfig,
  keymap = KeymapConfig,
}

---@class ConfidModule
local M = {}

M.config = DefaultConfig

---@param args Config?
M.setup = function(args)
  M.config = vim.tbl_deep_extend('force', M.config, args or {})
end

return M
