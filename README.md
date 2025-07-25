# DataViewer.nvim

<a href="https://github.com/neovim/neovim/releases/tag/stable"><img alt="Neovim-stable" src="https://img.shields.io/badge/Neovim-stable-blueviolet.svg?style=flat-square&logo=Neovim&logoColor=green" /></a>
<a href="https://github.com/vidocqh/data-viewer.nvim/search?l=lua"><img alt="Top Language" src="https://img.shields.io/github/languages/top/vidocqh/data-viewer.nvim?style=flat-square&label=Lua&logo=lua&logoColor=darkblue" /></a>
<a href="https://github.com/vidocqh/data-viewer.nvim/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/github/license/vidocqh/data-viewer.nvim?style=flat-square&logo=MIT&label=License" /></a>

Lightweight neovim plugin provides a table view for inspect data files such as `csv`, `tsv`

<p align='center'>
  <b>Floating View</b>
  <img width="2474" height="663" alt="image" src="https://github.com/user-attachments/assets/877c0c40-7091-4d15-8091-938a989602d4" />
</p>

<p align='center'>
  <b>Tab View</b>
  <img width="2495" height="681" alt="image" src="https://github.com/user-attachments/assets/ae861567-7839-4ba4-b58b-42845e35ffb2" />
</p>

### Supported filetypes

- csv (comma seperated)
- tsv (tab seperated)
- ssv (semicolon seperated)
- sqlite

## Requirements

- neovim >= 0.8
- [sqlite.lua](https://github.com/kkharji/sqlite.lua) (Optional)

## Usage

### Commands

- `:DataViewer` -- open with current file and auto detect filetype
- `:DataViewer [filetype]` -- open with current file with given filetype
- `:DataViewer [filepath] [filetype]` -- open with given file and given filetype
- `:DataViewerClose` -- closes the viewer

- `:DataViewerNextTable` -- switches to the next table if multiple are present in one sqlite file
- `:DataViewerPrevTable` -- switches to the previous

- `:DataViewerExpandCell` -- expands cell under cursor into floating window

- `:DataViewerToggleAdaptive` -- toggle if the table should be fixed to the buffer size and columns should be streched/truncated or if the table should be displayed as is

## Installation

### Lazy

```lua
require("lazy").setup({
  {
    'vidocqh/data-viewer.nvim',
    opts = {},
    dependencies = {
      "kkharji/sqlite.lua", -- Optional, sqlite support
    }
  },
})
```

### Paq

```lua
require('data-viewer').setup()
```

## Config

### Default config

```lua
local config = {
  autoDisplayDsv = true, -- Automatically display DSV files (csv, tsv, ssv)
  autoDisplaySqlite = true, -- Automatically display SQLite files
  showSqlSequenceTable = false, -- Show sqlite_sequence table in SQLite viewer
  maxLineEachTable = 100,
  columnColorEnable = true,
  columnColorRoulette = { -- Highlight groups for alternating columns
    "DataViewerColumn1",
    "DataViewerColumn2",
    "DataViewerColumn3",
  },
  delimiterHighlight = "DataViewerDelimiter", -- Highlight group for borders and delimiters
  focusTableHighlight = "DataViewerFocusTable", -- Highlight group for active table name
  view = {
    float = false, -- True will open in a floating window
    width = 0.8, -- Less than 1 means ratio to screen width, valid when float = true
    height = 0.8, -- Less than 1 means ratio to screen height, valid when float = true
    zindex = 50, -- Valid when float = true
    relative = true, -- If to open the window relative to the current buffer, valid when float = true
    adaptiveColumns = true, -- Automatically adjust column widths to fit window
  },
  keymap = {
    quit = "q",
    next_table = "<C-n>",
    prev_table = "<C-p>",
    toggle_adaptive = "<C-t>",
    expand_cell = "<C-e>",
  },
}
```

### Highlight Groups

The plugin uses theme-compatible highlight groups by default. You can customize the colors by configuring these options:

#### Column Colors

- `columnColorRoulette`: Array of highlight groups that cycle through columns
- `delimiterHighlight`: Highlight group for table borders and column separators
- `focusTableHighlight`: Highlight group for the active table name

#### Example: Custom Color Configuration

```lua
require('data-viewer').setup({
  columnColorEnable = true,
  columnColorRoulette = {
    "DataViewerColumn1",  -- Links to String (usually green/yellow)
    "DataViewerColumn2",  -- Links to Constant (usually orange/red)
    "DataViewerColumn3",  -- Links to Function (usually blue/purple)
  },
  delimiterHighlight = "DataViewerDelimiter", -- Non-italic Comment color
  focusTableHighlight = "DataViewerFocusTable", -- Active table name color -- Links to Title
})
```

#### Available Highlight Groups

- **DataViewerColumn1**: Column highlighting (links to `String` by default)
- **DataViewerColumn2**: Column highlighting (links to `Constant` by default)
- **DataViewerColumn3**: Column highlighting (links to `Function` by default)
- **DataViewerDelimiter**: Border/delimiter color (non-italic `Comment` color)
- **DataViewerFocusTable**: Active table name highlighting (links to `Title` by default)

All highlight groups are automatically created during setup and can be customized by users.

## Improvements

Feel free to open an issue or to submit a pull request.
