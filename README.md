# jira-nvim

A comprehensive Neovim plugin that integrates with [jira-cli](https://github.com/ankitpokhrel/jira-cli) to manage Jira from within Neovim using intuitive forms and quick commands.

![Neovim](https://img.shields.io/badge/Neovim-0.7+-green.svg)
![Lua](https://img.shields.io/badge/Lua-5.1+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## ✨ Features

- **📝 Interactive Forms**: Create issues and filter lists using intuitive form interfaces
- **⚡ Quick Commands**: Instant access to common Jira operations with preset filters
- **🔄 Smart Transitions**: Change issue status with context-aware state selection
- **🪟 Flexible UI**: Floating windows or split windows with customizable keymaps
- **🔍 Advanced Filtering**: Comprehensive issue filtering with support for all jira-cli options
- **🚀 LazyVim Integration**: Seamless integration with LazyVim with proper which-key support
- **🎯 Smart Navigation**: Auto-detect issue keys under cursor for quick actions
- **📊 Rich Display**: Syntax-highlighted output with interactive navigation

## 📋 Prerequisites

- **Neovim 0.7+**
- **[jira-cli](https://github.com/ankitpokhrel/jira-cli)** installed and configured
- **Properly configured Jira credentials** (see jira-cli documentation)

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim) (Recommended)

Create a new file `~/.config/nvim/lua/plugins/jira-nvim.lua`:

```lua
return {
  {
    "WillianPaiva/jira-nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-lua/plenary.nvim", -- For future async operations
    },
    opts = {
      jira_cmd = "jira", -- Ensure jira-cli is in your PATH
      use_floating_window = true,
      window_width = 0.8,
      window_height = 0.8,
      default_project = nil,
      keymaps = {
        close = "q",
        refresh = "<C-r>",
        open_browser = "<CR>",
        view_issue = "v",
        transition_issue = "t"
      }
    },
    keys = {
      -- Issue management
      { "<leader>ji", "<cmd>JiraIssueList<cr>", desc = "List Issues (Filter)" },
      { "<leader>jI", function() require("jira-nvim.form").my_issues() end, desc = "My Issues" },
      { "<leader>jT", function() require("jira-nvim.form").my_todo_issues() end, desc = "My TODO Issues" },
      { "<leader>jP", function() require("jira-nvim.form").my_in_progress_issues() end, desc = "My In Progress" },
      { "<leader>jr", function() require("jira-nvim.form").recent_issues() end, desc = "Recent Issues" },
      { "<leader>ju", function() require("jira-nvim.form").unassigned_issues() end, desc = "Unassigned Issues" },
      { "<leader>jh", function() require("jira-nvim.form").high_priority_issues() end, desc = "High Priority Issues" },
      { "<leader>jv", function() 
          vim.ui.input({
            prompt = "Issue Key: ",
            default = vim.fn.expand("<cword>")
          }, function(input)
            if input and input ~= "" then
              vim.cmd("JiraIssueView " .. input)
            end
          end)
        end, desc = "View Issue"
      },
      { "<leader>jc", "<cmd>JiraIssueCreate<cr>", desc = "Create Issue (Form)" },
      { "<leader>jt", function() 
          vim.ui.input({
            prompt = "Issue Key: ",
            default = vim.fn.expand("<cword>")
          }, function(issue_key)
            if issue_key and issue_key ~= "" then
              -- Get available transitions and show as options
              require('jira-nvim.cli').get_available_transitions(issue_key, function(err, states)
                if err then
                  -- Fallback to manual input if we can't get transitions
                  vim.ui.input({
                    prompt = "New State: ",
                  }, function(state)
                    if state and state ~= "" then
                      vim.cmd("JiraIssueTransition " .. issue_key .. " \"" .. state .. "\"")
                    end
                  end)
                else
                  -- Show available states as options
                  vim.ui.select(states, {
                    prompt = 'Select new state for ' .. issue_key .. ':',
                  }, function(choice)
                    if choice then
                      require('jira-nvim.cli').issue_transition(issue_key, choice)
                    end
                  end)
                end
              end)
            end
          end)
        end, desc = "Transition Issue"
      },
      
      -- Sprint management  
      { "<leader>js", "<cmd>JiraSprintList<cr>", desc = "List Sprints" },
      { "<leader>jS", "<cmd>JiraSprintList --current<cr>", desc = "Current Sprint" },
      
      -- Epic management
      { "<leader>je", "<cmd>JiraEpicList<cr>", desc = "List Epics" },
      
      -- Project/Board management
      { "<leader>jp", "<cmd>JiraProjectList<cr>", desc = "List Projects" },
      { "<leader>jb", "<cmd>JiraBoardList<cr>", desc = "List Boards" },
      
      -- Quick actions
      { "<leader>jo", function()
          local word = vim.fn.expand("<cword>")
          if word:match("^[A-Z]+-[0-9]+$") then
            vim.cmd("JiraOpen " .. word)
          else
            vim.cmd("JiraOpen")
          end
        end, desc = "Open in Browser"
      },
      
      -- Help
      { "<leader>j?", "<cmd>JiraHelp<cr>", desc = "Show Help" },
    },
    config = function(_, opts)
      require("jira-nvim").setup(opts)
    end,
  },
  
  -- Add which-key integration
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>j", group = "jira", icon = { icon = "󰌨 ", color = "blue" } },
      },
    },
  },
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'WillianPaiva/jira-nvim',
  config = function()
    require('jira-nvim').setup({
      -- Your configuration here
    })
  end,
  requires = { 'nvim-lua/plenary.nvim' }
}
```

### Manual Installation

1. Clone the repository:
```bash
git clone https://github.com/WillianPaiva/jira-nvim.git ~/.local/share/nvim/site/pack/plugins/start/jira-nvim
```

2. Add to your `init.lua`:
```lua
require('jira-nvim').setup()
```

## ⚙️ Configuration

### Default Configuration

```lua
require('jira-nvim').setup({
  jira_cmd = 'jira',                    -- Jira CLI command
  use_floating_window = true,           -- Use floating windows
  window_width = 0.8,                   -- Floating window width ratio
  window_height = 0.8,                  -- Floating window height ratio
  default_project = nil,                -- Default project key
  keymaps = {
    close = 'q',                        -- Close window
    refresh = '<C-r>',                  -- Refresh content
    open_browser = '<CR>',              -- Open issue in browser
    view_issue = 'v',                   -- View issue details
    transition_issue = 't'              -- Transition issue state
  }
})
```

## 🎯 Commands

### Core Commands

| Command | Description | Example |
|---------|-------------|---------|
| `:JiraIssueList [args]` | List/filter issues (opens form if no args) | `:JiraIssueList -a$(jira me) -s"To Do"` |
| `:JiraIssueView <key>` | View issue details | `:JiraIssueView PROJ-123` |
| `:JiraIssueCreate [args]` | Create new issue (opens form if no args) | `:JiraIssueCreate -tBug -s"Bug title"` |
| `:JiraIssueTransition <key> "state" ["comment"] ["assignee"] ["resolution"]` | Transition issue to new state | `:JiraIssueTransition PROJ-123 "To Be Reviewed"` |

### Sprint & Project Management

| Command | Description | Example |
|---------|-------------|---------|
| `:JiraSprintList [args]` | List sprints | `:JiraSprintList --current` |
| `:JiraEpicList [args]` | List epics | `:JiraEpicList --table` |
| `:JiraProjectList [args]` | List projects | `:JiraProjectList` |
| `:JiraProjectCreate [args]` | Create new project | `:JiraProjectCreate --key=PROJ --name="New Project" --template=scrum` |
| `:JiraBoardList` | List boards | `:JiraBoardList` |

### Utility Commands

| Command | Description | Example |
|---------|-------------|---------|
| `:JiraOpen [key]` | Open in browser | `:JiraOpen PROJ-123` |
| `:JiraHelp` | Show plugin help | `:JiraHelp` |

## ⌨️ Default Keymaps (LazyVim)

### Issue Management
- `<leader>ji` - **List Issues (Filter Form)** - Opens advanced filtering form
- `<leader>jI` - **My Issues** - Issues assigned to me
- `<leader>jT` - **My TODO Issues** - My issues with "To Do" status
- `<leader>jP` - **My In Progress** - My issues currently in progress
- `<leader>jr` - **Recent Issues** - Issues created in last 7 days
- `<leader>ju` - **Unassigned Issues** - Issues with no assignee
- `<leader>jh` - **High Priority Issues** - High priority issues only
- `<leader>jv` - **View Issue** - View specific issue (with smart word detection)
- `<leader>jc` - **Create Issue (Form)** - Create issue using interactive form
- `<leader>jt` - **Transition Issue** - Change issue status with available state options

### Sprint & Epic Management
- `<leader>js` - **List Sprints**
- `<leader>jS` - **Current Sprint**
- `<leader>je` - **List Epics**

### Project & Board Management
- `<leader>jp` - **List Projects**
- `<leader>jb` - **List Boards**

### Quick Actions
- `<leader>jo` - **Open in Browser** (smart detection of issue keys)
- `<leader>j?` - **Show Help**

### In Jira Windows
- `q` - Close window
- `<C-r>` - Refresh content (planned)
- `<CR>` - Open issue under cursor in browser
- `v` - View details of issue under cursor
- `t` - Transition current issue state (shows available state options)

## 🔄 Issue Transitions

The plugin provides intelligent issue state transitions with context-aware options:

### Smart State Selection
- **Available States Detection**: Automatically fetches valid transition states for each issue
- **Interactive Selection**: Uses `vim.ui.select` to show available options
- **Fallback Support**: Falls back to manual input if states can't be retrieved
- **Context Awareness**: Works both globally and within issue view buffers

### Transition Methods
1. **Global Keymap** (`<leader>jt`): Prompts for issue key, then shows available states
2. **In-Buffer Keymap** (`t` by default, customizable): Auto-detects issue from buffer title
3. **Command Line** (`:JiraIssueTransition PROJ-123 "State"`): Direct command execution

### Customization
```lua
-- Custom transition keymap (avoiding vim's default 't')
keymaps = {
  transition_issue = '<M-t>'  -- Alt+t instead of 't'
}
```

## 📝 Interactive Forms

### Issue Creation Form (`<leader>jc`)

Opens a comprehensive form with fields for:
- **Type** (Bug, Story, Task, Epic, etc.)
- **Summary** (required)
- **Priority** (Low, Medium, High, Critical)
- **Assignee**
- **Labels** (comma-separated)
- **Components** (comma-separated)
- **Fix Version**
- **Description** (multi-line)

**Form Controls:**
- Fill out fields and press `<leader>js` or `<C-s>` to submit
- Press `q` to cancel

### Issue List Filter Form (`<leader>ji`)

Advanced filtering form with:
- **Common Filters**: Assignee, Status, Priority, Type, Labels, Components
- **Time Filters**: Created, Updated, Created Before
- **Advanced**: JQL Query, Order By, Reverse Order

**Examples of filter values:**
- **Assignee**: `$(jira me)`, `username`, or `x` for unassigned
- **Status**: `"To Do"`, `"In Progress"`, `"Done"`
- **Priority**: `Low`, `Medium`, `High`, `Critical`
- **Created**: `-7d`, `week`, `month`, `-1h`, `-30m`
- **Labels**: `backend,frontend` (comma-separated)

## 🚀 Usage Examples

### Quick Daily Workflow

```bash
# Check my TODO items for standup
<leader>jT

# Check what I'm currently working on
<leader>jP

# Create a new bug
<leader>jc
# (Fill out the form and submit)

# View a specific issue (cursor on PROJ-123)
<leader>jv

# Transition an issue (cursor on PROJ-123)
<leader>jt
# (Shows available states like "In Progress", "Done", "To Be Reviewed")

# Or while viewing an issue, press 't' (or your custom keymap) to transition
# (automatically detects issue and shows available state options)

# Open issue in browser
<leader>jo
```

### Advanced Filtering

```bash
# Open advanced filter form
<leader>ji

# In the form, set:
# Assignee: $(jira me)
# Status: "In Progress"
# Priority: High
# Created: -1w
# Press <leader>js to apply
```

### Direct Commands (Power Users)

```vim
" List my high priority bugs from this week
:JiraIssueList -a$(jira me) -tBug -yHigh --created week

" Create a critical bug quickly
:JiraIssueCreate -tBug -s"Critical production issue" -yCritical --no-input

" Transition issue with comment
:JiraIssueTransition PROJ-123 "Done" "Completed development and testing"

" Transition to multi-word state
:JiraIssueTransition PROJ-123 "To Be Reviewed"

" View current sprint issues
:JiraSprintList --current
```

## 🔧 Troubleshooting

### Jira CLI not found
```bash
# Verify jira-cli is installed and in PATH
which jira
jira version
```

### Authentication issues
```bash
# Configure Jira credentials
jira init
```

### Permission errors
Check that your Jira user has appropriate permissions for the operations you're trying to perform.

### Form submission issues
- Ensure you're using `<leader>js` or `<C-s>` in insert mode to submit forms
- Check that required fields (Type and Summary for issue creation) are filled
- Verify jira-cli is working: `jira issue list` in terminal

## 🛠️ Development

### Local Development

1. Clone the repository:
```bash
git clone https://github.com/WillianPaiva/jira-nvim.git
cd jira-nvim
```

2. For local development with LazyVim, update your plugin config:
```lua
{
  dir = "/path/to/your/jira-nvim", -- Local development path
  name = "jira-nvim",
  -- ... rest of config
}
```

3. Test your changes and restart Neovim.

### Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Test thoroughly
5. Commit your changes: `git commit -m 'Add amazing feature'`
6. Push to the branch: `git push origin feature/amazing-feature`
7. Open a Pull Request

## 📜 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **[jira-cli](https://github.com/ankitpokhrel/jira-cli)** - The excellent CLI tool this plugin wraps
- **[LazyVim](https://github.com/LazyVim/LazyVim)** - Amazing Neovim configuration framework
- **Neovim community** - For the fantastic plugin ecosystem

## 📋 Complete Feature Summary

### 🎯 Issue Management
- **List & Filter**: Advanced filtering with forms or direct commands
- **View Details**: Rich issue display with interactive navigation
- **Create Issues**: Form-based creation with all field support
- **Smart Transitions**: Context-aware state changes with available options
- **Quick Actions**: Auto-detect issue keys, open in browser

### 🔄 Workflow Integration  
- **Sprint Management**: List current/all sprints
- **Epic Tracking**: View and manage epics
- **Project Overview**: Browse projects and boards
- **Smart Navigation**: Cursor-based issue detection

### ⌨️ Flexible Interface
- **Global Keymaps**: Quick access from anywhere (`<leader>j*`)
- **Buffer Keymaps**: Context actions within Jira windows (`t`, `v`, `<CR>`)
- **Customizable**: All keymaps can be customized
- **Form-based**: Interactive forms for complex operations

### 🚀 Enhanced Experience
- **LazyVim Integration**: Seamless setup with which-key support
- **Floating/Split Windows**: Choose your preferred display mode
- **Error Handling**: Graceful fallbacks and helpful error messages
- **Performance**: Async operations, no blocking

## 📚 Integration with jira-cli

This plugin is a comprehensive wrapper around [jira-cli](https://github.com/ankitpokhrel/jira-cli). All the filtering and querying capabilities of jira-cli are available through intuitive forms and commands.

For detailed information about available flags and options, refer to the [jira-cli documentation](https://github.com/ankitpokhrel/jira-cli).

---

<div align="center">
  <sub>Built with ❤️ for the Neovim community</sub>
</div>