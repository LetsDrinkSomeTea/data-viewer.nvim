vim.api.nvim_create_user_command("DataViewer", require("data-viewer").start, { nargs = "?" })
vim.api.nvim_create_user_command("DataViewerNextTable", require("data-viewer").next_table, {})
vim.api.nvim_create_user_command("DataViewerPrevTable", require("data-viewer").prev_table, {})
vim.api.nvim_create_user_command("DataViewerClose", require("data-viewer").close_tables, {})
vim.api.nvim_create_user_command("DataViewerToggleAdaptive", require("data-viewer").toggle_adaptive, {})
vim.api.nvim_create_user_command("DataViewerExpandCell", require("data-viewer").expand_cell, {})

vim.api.nvim_set_hl(0, "DataViewerColumn0", { fg = "#bb0000" })
vim.api.nvim_set_hl(0, "DataViewerColumn1", { fg = "#00bb00" })
vim.api.nvim_set_hl(0, "DataViewerColumn2", { fg = "#0000bb" })

vim.api.nvim_set_hl(0, "DataViewerFocusTable", { fg = "#bbbb00" })

vim.filetype.add({
  extension = {
    sqlite3 = "sqlite",
    sqlite = "sqlite",
  },
})
