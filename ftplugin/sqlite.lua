if vim.b.did_data_viewer_ftplugin == 1 then
  return
end

local config = require('data-viewer.config')

if config.config.autoDisplaySqlite then
  vim.schedule(function()
    require('data-viewer').start({ args = '', force_replace = true })
  end)
end
