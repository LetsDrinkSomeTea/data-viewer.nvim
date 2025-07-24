if vim.b.did_data_viewer_ftplugin == 1 then
  return
end

local config = require("data-viewer.config")

-- Set wrap behavior for data viewer file types
vim.api.nvim_buf_set_option(0, "wrap", config.config.view.wrap)

if config.config.autoDisplayWhenOpenFile then
  vim.schedule(function () require("data-viewer").start({ args = "" }) end)
end
