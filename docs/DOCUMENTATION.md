# jira-nvim Documentation

Welcome to the comprehensive documentation for jira-nvim. This document covers all features, configurations, and usage patterns for the plugin.

## Table of Contents

1. [Installation](#installation)
2. [Configuration](#configuration)
3. [Core Features](#core-features)
   - [Issue Management](#issue-management)
   - [Dashboard](#dashboard)
   - [Context Awareness](#context-awareness)
   - [Enhanced Forms](#enhanced-forms)
   - [Git Integration](#git-integration)
   - [LSP Integration](#lsp-integration)
4. [Advanced Usage](#advanced-usage)
   - [JQL Searching](#jql-searching)
   - [Sprint Management](#sprint-management)
   - [Caching System](#caching-system)
   - [Error Handling](#error-handling)
5. [Keymaps](#keymaps)
6. [Commands](#commands)
7. [Troubleshooting](#troubleshooting)
8. [API Reference](#api-reference)
9. [Development & Contribution](#development--contribution)

## Installation

### Prerequisites

- **Neovim 0.7+**
- **[plenary.nvim](https://github.com/nvim-lua/plenary.nvim)** for HTTP requests
- **Jira account with API token** (obtain from [Atlassian API tokens](https://id.atlassian.com/manage-profile/security/api-tokens))

### Using Lazy.nvim (Recommended)

Create a new file `~/.config/nvim/lua/plugins/jira-nvim.lua`:

```lua
return {
  {
    "WillianPaiva/jira-nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-lua/plenary.nvim", -- For HTTP operations
    },
    opts = {
      -- Basic configuration (see Configuration section for details)
      jira_url = "https://your-domain.atlassian.net",
      jira_email = "your.email@example.com",
      jira_api_token = "your-api-token",
      project_key = "PROJ",
    },
    keys = {
      -- Dashboard
      { "<leader>jd", "<cmd>JiraDashboard<cr>", desc = "Jira Dashboard" },
      
      -- Issue management
      { "<leader>ji", "<cmd>JiraIssueList<cr>", desc = "List Issues (Filter)" },
      { "<leader>jc", "<cmd>JiraIssueCreate<cr>", desc = "Create Issue" },
      -- See Configuration section for more keybindings
    },
    config = function(_, opts)
      require("jira-nvim").setup(opts)
    end,
  },
}
```

### Using Packer.nvim

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

## Configuration

### Comprehensive Configuration Options

```lua
require('jira-nvim').setup({
  -- API Connection Settings
  jira_url = 'https://your-domain.atlassian.net',  -- Your Jira instance URL
  jira_email = 'your.email@example.com',          -- Your Jira email
  jira_api_token = 'your-api-token',              -- Your Jira API token
  auth_type = 'basic',                            -- 'basic' (cloud) or 'bearer' (server)
  
  -- Project Settings
  project_key = 'PROJ',                           -- Your default project key
  default_board = '1234',                         -- Your default board ID
  
  -- UI Settings
  use_floating_window = true,                     -- Use floating windows
  window_width = 0.8,                             -- Floating window width ratio
  window_height = 0.8,                            -- Floating window height ratio
  
  -- Integration Options
  enable_lsp_integration = false,                 -- Enable LSP hover and code actions
  enable_git_integration = true,                  -- Enable Git workflow features
  
  -- Caching Options
  enable_caching = true,                          -- Enable API response caching
  cache_ttl = 300,                                -- Cache time-to-live in seconds
  cache_size = 100,                               -- Max items per cache type
  
  -- Error Handling
  enhanced_error_handling = true,                 -- Enable friendly error messages
  
  -- Keymaps
  keymaps = {
    close = 'q',                                  -- Close window
    refresh = '<C-r>',                            -- Refresh content
    open_browser = '<CR>',                        -- Open issue in browser
    view_issue = 'v',                             -- View issue details
    transition_issue = 't',                       -- Transition issue state
    comment_issue = 'c',                          -- Add comment to issue
    view_comments = 'C',                          -- View issue comments
    assign_issue = 'a',                           -- Assign issue
    watch_issue = 'w',                            -- Add watcher to issue
    toggle_bookmark = 'b',                        -- Toggle bookmark
    show_history = 'h',                           -- Show history
    show_bookmarks = 'B',                         -- Show bookmarks
    fuzzy_search = '/'                            -- Fuzzy search
  }
})
```

### Authentication Setup

To configure authentication interactively, run:
```vim
:JiraSetup
```

This will walk you through setting up your Jira credentials and project settings. Credentials are securely stored in `~/.config/nvim/jira-nvim/auth.json`.

### Finding Your Board ID

To find your board ID (needed for sprint features):

1. Run `:JiraSetup` and follow the prompts to set up your credentials and project
2. Run `:JiraShowBoards` to see boards for your project with their IDs
3. Set your default board with `:JiraSetDefaultBoard <id>`

## Core Features

### Issue Management

jira-nvim provides comprehensive issue management capabilities directly in Neovim:

#### Listing and Filtering Issues

Use `:JiraIssueList` to open the filtering form or pass JQL parameters directly:

```vim
" List all issues assigned to you in the 'To Do' state
:JiraIssueList -a$(jira me) -s"To Do"

" List high priority bugs
:JiraIssueList -yHigh -tBug
```

Preset commands:
- `:JiraMyIssues` - Show issues assigned to you
- `:JiraHighPriorityIssues` - Show high priority issues
- `:JiraUnassignedIssues` - Show issues with no assignee

#### Viewing Issues

```vim
" View a specific issue
:JiraIssueView PROJ-123
```

Within issue view, you can:
- Press `t` to transition the issue to another state
- Press `c` to add a comment
- Press `a` to assign the issue
- Press `<CR>` to open the issue in your browser

#### Creating Issues

```vim
" Open the issue creation form
:JiraIssueCreate
```

The issue creation form supports:
- **Markdown Preview**: Press `<C-p>` to toggle a live preview of your description
- **Issue Templates**: Press `<C-t>` to apply a template based on the selected issue type
- **Smart Autocompletion**: Field-aware suggestions for users, components, and issue types

#### Transitions

You can transition issues through several methods:

1. In issue view, press `t` to see available states
2. From anywhere, use:
   ```vim
   :JiraIssueTransition PROJ-123 "In Progress"
   ```
3. With comment:
   ```vim
   :JiraIssueTransition PROJ-123 "In Progress" "Starting work on this"
   ```

### Dashboard

The dashboard feature provides an at-a-glance view of your Jira workload:

```vim
" Open the personalized dashboard
:JiraDashboard
```

The dashboard shows:
- Your assigned issues organized by status
- Issues in your current active sprint
- Recent activity from the past 7 days
- High priority issues that need attention

```vim
" View personal Jira statistics
:JiraStats
```

The statistics view displays metrics about your work items, including:
- Issue count by status
- Issue count by priority
- Average resolution time
- Recent activity metrics

### Context Awareness

The context awareness features detect and interact with Jira issues in your working environment:

```vim
" Show Jira issues related to your current git branch, files, or commits
:JiraContext
```

Context detection works by:
- Extracting issue keys from git branch names
- Finding issue keys in commit messages
- Scanning the current file for issue references

When an issue key is detected under your cursor, you can:
```vim
" View the issue details
:JiraViewUnderCursor

" Open the issue in browser
:JiraOpenUnderCursor
```

### Enhanced Forms

jira-nvim provides enhanced form interfaces for creating and filtering issues:

#### Issue Creation Form

The issue creation form provides a structured way to create issues with full Jira field support:

- **Field Structure**: All common Jira fields with appropriate defaults
- **Live Markdown Preview**: Press `<C-p>` to see your formatted description
- **Issue Templates**: Press `<C-t>` to get a template based on issue type
- **Smart Autocompletion**: Context-aware field suggestions

Controls:
- `<leader>js` or `<C-s>` to submit the form
- `q` to cancel
- `<C-p>` to toggle markdown preview
- `<C-t>` to apply issue type template

#### Issue List Filter Form

The filtering form provides a powerful interface for building complex Jira queries:

- **Common Filters**: Assignee, Status, Priority, Type, etc.
- **Time Filters**: Created, Updated, Created Before
- **Advanced Options**: JQL, Order By, Reverse Order
- **Smart Autocompletion**: Field-aware filter suggestions

### Git Integration

jira-nvim seamlessly integrates with your Git workflow:

```vim
" Create a branch from a Jira issue with prefix selection
:JiraGitBranch

" Show commit history with linked Jira issues
:JiraGitCommitHistory

" Link current HEAD commit to a Jira issue
:JiraGitLinkCommit HEAD PROJ-123

" Update Jira issue with branch information
:JiraGitUpdateIssue

" Install Git hooks for automatic Jira integration
:JiraInstallGitHooks
```

The Git integration supports:

1. **Branch Creation**: Create branches with issue key and sanitized summary
2. **Commit Linking**: Automatically add issue keys to commit messages
3. **Issue Updates**: Update Jira with Git branch/commit information
4. **Git Hooks**: Automated integration through post-checkout and post-commit hooks

### LSP Integration

jira-nvim provides Language Server Protocol integration for Jira issues in your code:

```vim
" Enable LSP integration features
:JiraEnableLsp

" Highlight Jira issue keys in current buffer
:JiraHighlightKeys
```

LSP features include:
1. **Hover Information**: See issue details when hovering over issue keys
2. **Code Actions**: Create links or transitions directly from issue keys in code
3. **Syntax Highlighting**: Visual indication of issue status directly in code
4. **Issue Status Updates**: See real-time issue status in your code comments

## Advanced Usage

### JQL Searching

You can use Jira Query Language (JQL) directly for complex searches:

```vim
" Use JQL search directly
:JiraIssueList -q"project = PROJ AND status != Done AND priority in (High, Highest)"
```

Common JQL patterns:
- `assignee = currentUser() AND status = "In Progress"`
- `project = PROJ AND fixVersion = "1.0.0"`
- `sprint in openSprints() AND type = Bug`

### Sprint Management

jira-nvim provides comprehensive sprint management capabilities:

```vim
" List all sprints
:JiraSprintList

" Show current active sprint
:JiraSprintList --current
:JiraCurrentSprint
```

Within sprint views, you can:
- View sprint progress and statistics
- See issues organized by status
- Transition issues directly from the sprint view

### Caching System

jira-nvim includes a smart caching system to improve performance:

```vim
" View cache statistics
:JiraCacheStats

" Clear specific cache type
:JiraCacheClear issues

" Clear all caches
:JiraCacheClear
```

The caching system:
- Stores API responses with configurable TTL
- Reduces API calls for common operations
- Provides performance metrics
- Automatically pruner older entries

### Error Handling

jira-nvim includes enhanced error handling with user-friendly messages:

```vim
" Show troubleshooting guide
:JiraTroubleshoot
```

The error handling system:
- Categorizes common API errors
- Provides contextual troubleshooting tips
- Shows potential solutions for connectivity issues
- Offers guidance for permission problems

## Keymaps

### Global Keymaps (LazyVim Example)

```lua
keys = {
  -- Dashboard
  { "<leader>jd", "<cmd>JiraDashboard<cr>", desc = "Jira Dashboard" },
  
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
  
  -- Context awareness
  { "<leader>jx", "<cmd>JiraContext<cr>", desc = "Show Jira Context" },
  { "<leader>jo", function()
      local word = vim.fn.expand("<cword>")
      if word:match("^[A-Z]+-[0-9]+$") then
        vim.cmd("JiraOpen " .. word)
      else
        vim.cmd("JiraOpen")
      end
    end, desc = "Open in Browser"
  },
  
  -- Git integration
  { "<leader>jgb", "<cmd>JiraGitBranch<cr>", desc = "Create Git Branch" },
  { "<leader>jgc", "<cmd>JiraGitCommitHistory<cr>", desc = "Git Commit History" },
  
  -- Help
  { "<leader>j?", "<cmd>JiraHelp<cr>", desc = "Show Help" },
}
```

### In Jira Windows

These keymaps work when viewing Jira content:

- `q` - Close window
- `<C-r>` - Refresh current view
- `<CR>` - Open issue under cursor in browser
- `v` - View details of issue under cursor
- `t` - Transition issue state (shows available options)
- `c` - Add comment to issue
- `C` - View recent comments
- `a` - Assign issue to user
- `b` - Toggle bookmark for issue
- `h` - Show issue history
- `B` - Show bookmarks

### In Issue Forms

- `<leader>js` or `<C-s>` - Submit form
- `q` - Cancel form
- `<C-p>` - Toggle markdown preview (issue creation)
- `<C-t>` - Apply issue type template (issue creation)

## Commands

### Core Commands

| Command | Description | Example |
|---------|-------------|---------|
| `:JiraIssueList [args]` | List/filter issues | `:JiraIssueList -a$(jira me) -s"To Do"` |
| `:JiraIssueView <key>` | View issue details | `:JiraIssueView PROJ-123` |
| `:JiraIssueCreate [args]` | Create new issue | `:JiraIssueCreate -tBug -s"Bug title"` |
| `:JiraIssueTransition <key> <state> [comment]` | Transition issue | `:JiraIssueTransition PROJ-123 "In Progress"` |
| `:JiraIssueComment <key> [comment]` | Comment on issue | `:JiraIssueComment PROJ-123 "Fixed"` |
| `:JiraIssueAssign <key> <user>` | Assign issue | `:JiraIssueAssign PROJ-123 me` |
| `:JiraOpen [key]` | Open in browser | `:JiraOpen PROJ-123` |

### Dashboard & Context Commands

| Command | Description |
|---------|-------------|
| `:JiraDashboard` | Show personalized Jira dashboard |
| `:JiraStats` | Show personal Jira statistics |
| `:JiraContext` | Show Jira context from current branch/file |
| `:JiraViewUnderCursor` | View Jira issue under cursor |
| `:JiraOpenUnderCursor` | Open Jira issue under cursor in browser |

### Git Integration Commands

| Command | Description |
|---------|-------------|
| `:JiraGitBranch` | Create branch from issue with prefix selection |
| `:JiraGitCommitHistory` | Show commit history with Jira links |
| `:JiraGitLinkCommit [hash] [key]` | Link a commit to an issue |
| `:JiraGitUpdateIssue` | Update issue with branch info |
| `:JiraInstallGitHooks` | Install Git hooks for Jira integration |

### LSP Integration Commands

| Command | Description |
|---------|-------------|
| `:JiraEnableLsp` | Enable LSP integration features |
| `:JiraHighlightKeys` | Highlight issue keys in current buffer |

### Caching Commands

| Command | Description |
|---------|-------------|
| `:JiraCacheStats` | Show API cache statistics |
| `:JiraCacheClear [type]` | Clear API cache |

## Troubleshooting

### Common Issues

#### Authentication Issues
- Verify your Jira URL format (should be `https://your-domain.atlassian.net`)
- Check that your email matches the one registered with Atlassian
- Ensure your API token is valid and not expired
- Run `:JiraSetup` to reconfigure credentials

#### API Errors
- **401 Error**: Authentication failed, check your credentials
- **403 Error**: Permission denied, check your Jira permissions
- **404 Error**: Resource not found, check issue keys and project keys
- **400 Error**: Bad request, check your input parameters

#### Form Submission Issues
- Ensure you're using `<leader>js` or `<C-s>` to submit forms
- Check that required fields (Type and Summary for issue creation) are filled
- Check network connectivity to your Jira instance

#### Git Integration Issues
- Ensure Git is installed and available in your PATH
- Check that you're in a valid Git repository
- Verify Git permissions for hook installation

#### LSP Integration Issues
- Ensure you're using Neovim 0.7+ for LSP features
- Check that the LSP client is properly initialized
- Verify LSP integration is enabled in your configuration

### Diagnostics

Run the following command to check your Jira connection:
```vim
:JiraTestConnection
```

To see your current configuration status:
```vim
:JiraStatus
```

For detailed troubleshooting:
```vim
:JiraTroubleshoot
```

## API Reference

jira-nvim exposes several Lua modules you can use in your custom configurations:

### Core API

```lua
local jira = require('jira-nvim')
local api = require('jira-nvim.api')
local cli = require('jira-nvim.cli')
local form = require('jira-nvim.form')
```

### Issue Management

```lua
-- Get issue details
api.get_issue("PROJ-123", function(err, issue)
  if err then
    print("Error: " .. err)
    return
  end
  
  -- Use issue data
  print("Title: " .. issue.fields.summary)
end)

-- Create a new issue
cli.issue_create('-tBug -s"Bug title" -b"Description"')

-- Transition an issue
cli.issue_transition("PROJ-123", "In Progress", "Starting work")
```

### Dashboard & Context

```lua
local dashboard = require('jira-nvim.dashboard')
local context = require('jira-nvim.context')

-- Show dashboard
dashboard.show_dashboard()

-- Get current context
local issue_key = context.detect_issue_key_from_branch()
if issue_key then
  cli.issue_view(issue_key)
end
```

### Git Integration

```lua
local git = require('jira-nvim.git')

-- Create a branch for an issue
git.create_branch_for_issue("PROJ-123", "feature")

-- Link a commit to an issue
git.link_commit_to_issue("HEAD", "PROJ-123")
```

### Form Enhancement API

```lua
local form_enhancements = require('jira-nvim.form_enhancements')

-- Apply a template to a buffer
form_enhancements.apply_issue_template(buf, "Bug")

-- Toggle markdown preview
form_enhancements.toggle_markdown_preview(buf, win)

-- Set up autocompletion
form_enhancements.setup_autocompletion(buf)
```

## Development & Contribution

### Setting Up Development Environment

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

### Plugin Structure

- `lua/jira-nvim/init.lua`: Entry point and commands registration
- `lua/jira-nvim/config.lua`: Configuration management
- `lua/jira-nvim/api.lua`: Jira REST API communication
- `lua/jira-nvim/cli.lua`: Command interface layer
- `lua/jira-nvim/ui.lua`: UI components and display
- `lua/jira-nvim/form.lua`: Form interfaces
- `lua/jira-nvim/form_enhancements.lua`: Enhanced form capabilities
- `lua/jira-nvim/dashboard.lua`: Dashboard implementation
- `lua/jira-nvim/context.lua`: Context awareness features
- `lua/jira-nvim/git.lua`: Git integration
- `lua/jira-nvim/lsp.lua`: LSP integration
- `lua/jira-nvim/cache.lua`: Caching system
- `lua/jira-nvim/errors.lua`: Error handling system

### Debugging

- Set `vim.g.jira_nvim_debug = true` to enable debug logging
- Check logs in `~/.cache/nvim/jira-nvim/debug.log`
- Use `utils.debug(message)` for custom debug messages

---

## Support

If you encounter any issues or have questions, please open an issue on the [GitHub repository](https://github.com/WillianPaiva/jira-nvim/issues).

---

<div align="center">
  <sub>Built with ❤️ for the Neovim community</sub>
</div>