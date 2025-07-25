-- Return a table { headers = headers, bodyLines = bodyLines }
-- headers: string[]                  -- Contains all column names by display order
-- bodyLines: table<string, string>[] -- Array of tables, each table represents a line by type {[columnName]: value}

---@class Parsers
local M = {
  csv = require('data-viewer.parser.fsv')('csv', ','),
  tsv = require('data-viewer.parser.fsv')('tsv', '\t'),
  ssv = require('data-viewer.parser.fsv')('ssv', ';'),
  sqlite = require('data-viewer.parser.sqlite'),
  xlsx = require('data-viewer.parser.excel'),
  xls = require('data-viewer.parser.excel'),
  ods = require('data-viewer.parser.excel'),
}

return M
