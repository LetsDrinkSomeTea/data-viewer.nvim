vim.api.nvim_create_user_command('DataViewer', require('data-viewer').start, { nargs = '?' })
vim.api.nvim_create_user_command('DataViewerNextTable', require('data-viewer').next_table, {})
vim.api.nvim_create_user_command('DataViewerPrevTable', require('data-viewer').prev_table, {})
vim.api.nvim_create_user_command('DataViewerClose', require('data-viewer').close_tables, {})
vim.api.nvim_create_user_command(
  'DataViewerToggleAdaptive',
  require('data-viewer').toggle_adaptive,
  {}
)
vim.api.nvim_create_user_command('DataViewerExpandCell', require('data-viewer').expand_cell, {})
vim.api.nvim_create_user_command('DataViewerNextPage', require('data-viewer').next_page, {})
vim.api.nvim_create_user_command('DataViewerPrevPage', require('data-viewer').prev_page, {})

vim.filetype.add({
  extension = {
    sqlite3 = 'sqlite',
    sqlite = 'sqlite',
    xlsx = 'xlsx',
    xls = 'xls',
    ods = 'ods',
  },
})

-- Override zip detection for Excel files
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'zip',
  callback = function()
    local filename = vim.fn.expand('%:t')
    if filename:match('%.xlsx$') then
      vim.bo.filetype = 'xlsx'
    elseif filename:match('%.xls$') then
      vim.bo.filetype = 'xls'
    elseif filename:match('%.ods$') then
      vim.bo.filetype = 'ods'
    end
  end,
})
