# jira-nvim API Reference

This document provides a detailed API reference for developers who want to extend or integrate with jira-nvim.

## Core Modules

jira-nvim is organized into several modular components, each responsible for a specific aspect of functionality:

### Module Overview

| Module | Description |
|--------|-------------|
| `jira-nvim` | Main entry point and setup |
| `jira-nvim.api` | Direct Jira REST API communication |
| `jira-nvim.cli` | Command-line interface for Jira operations |
| `jira-nvim.config` | Configuration management |
| `jira-nvim.ui` | User interface rendering |
| `jira-nvim.form` | Interactive form interfaces |
| `jira-nvim.form_enhancements` | Enhanced form features (markdown, autocompletion) |
| `jira-nvim.dashboard` | Dashboard implementation |
| `jira-nvim.context` | Context awareness features |
| `jira-nvim.git` | Git integration features |
| `jira-nvim.lsp` | LSP/editor integration |
| `jira-nvim.cache` | Caching system |
| `jira-nvim.errors` | Error handling and troubleshooting |
| `jira-nvim.utils` | Utility functions |
| `jira-nvim.user` | User management and authentication |
| `jira-nvim.search` | Search functionality |

## Main Module (`jira-nvim`)

```lua
local jira = require('jira-nvim')
```

### `jira.setup(opts)`

Sets up the plugin with the provided options.

**Parameters:**
- `opts` (table): Configuration options (see [Configuration](#configuration) section)

**Example:**
```lua
require('jira-nvim').setup({
  jira_url = 'https://your-domain.atlassian.net',
  jira_email = 'your.email@example.com',
  jira_api_token = 'your-api-token',
})
```

## API Module (`jira-nvim.api`)

```lua
local api = require('jira-nvim.api')
```

This module provides direct access to the Jira REST API.

### Authentication Functions

#### `api.setup()`

Configures the API client with stored credentials.

**Returns:** `boolean` - Success status

#### `api.get_current_user(callback)`

Retrieves information about the current user.

**Parameters:**
- `callback` (function): Function to call with results, receives `(error, user_data)`

**Example:**
```lua
api.get_current_user(function(err, user)
  if not err then
    print("Logged in as: " .. user.displayName)
  end
end)
```

### Issue Functions

#### `api.get_issue(issue_key, callback)`

Retrieves detailed information about an issue.

**Parameters:**
- `issue_key` (string): Jira issue key (e.g., "PROJ-123")
- `callback` (function): Function to call with results, receives `(error, issue_data)`

**Example:**
```lua
api.get_issue("PROJ-123", function(err, issue)
  if not err then
    print("Issue summary: " .. issue.fields.summary)
  end
end)
```

#### `api.create_issue(data, callback)`

Creates a new issue in Jira.

**Parameters:**
- `data` (table): Issue data with fields
- `callback` (function): Function to call with results, receives `(error, created_issue)`

**Example:**
```lua
api.create_issue({
  fields = {
    project = { key = "PROJ" },
    issuetype = { name = "Bug" },
    summary = "Test issue",
    description = "This is a test issue"
  }
}, function(err, issue)
  if not err then
    print("Created issue: " .. issue.key)
  end
end)
```

#### `api.add_comment(issue_key, comment, callback)`

Adds a comment to an issue.

**Parameters:**
- `issue_key` (string): Jira issue key
- `comment` (string): Comment text
- `callback` (function): Function to call with results, receives `(error, comment_data)`

### Search Functions

#### `api.search_issues(jql, max_results, callback)`

Searches for issues using JQL.

**Parameters:**
- `jql` (string): JQL query string
- `max_results` (number, optional): Maximum number of results to return
- `callback` (function): Function to call with results, receives `(error, search_results)`

**Example:**
```lua
api.search_issues("project = PROJ AND status = 'In Progress'", 10, function(err, results)
  if not err then
    print("Found " .. results.total .. " issues")
    for _, issue in ipairs(results.issues) do
      print(issue.key .. ": " .. issue.fields.summary)
    end
  end
end)
```

### Project Functions

#### `api.get_projects(callback)`

Retrieves all accessible projects.

**Parameters:**
- `callback` (function): Function to call with results, receives `(error, projects)`

#### `api.get_project(project_key, callback)`

Retrieves information about a specific project.

**Parameters:**
- `project_key` (string): Project key
- `callback` (function): Function to call with results, receives `(error, project)`

### Board Functions

#### `api.get_boards(callback)`

Retrieves all accessible boards.

**Parameters:**
- `callback` (function): Function to call with results, receives `(error, boards)`

#### `api.get_project_boards(project_key, callback)`

Retrieves boards for a specific project.

**Parameters:**
- `project_key` (string): Project key
- `callback` (function): Function to call with results, receives `(error, boards)`

### Sprint Functions

#### `api.get_sprints(board_id, callback)`

Retrieves sprints for a specific board.

**Parameters:**
- `board_id` (string): Board ID
- `callback` (function): Function to call with results, receives `(error, sprints)`

### User Functions

#### `api.find_users(query, callback)`

Searches for users.

**Parameters:**
- `query` (string): Search query
- `callback` (function): Function to call with results, receives `(error, users)`

## CLI Module (`jira-nvim.cli`)

```lua
local cli = require('jira-nvim.cli')
```

This module provides command-line interface functions for Jira operations.

### Issue Management

#### `cli.issue_list(args)`

Lists issues based on provided arguments.

**Parameters:**
- `args` (string, optional): Command-line arguments for filtering

**Example:**
```lua
cli.issue_list('-a"currentUser()" -s"To Do"')
```

#### `cli.issue_view(issue_key, comment_count)`

Views detailed information about an issue.

**Parameters:**
- `issue_key` (string): Jira issue key
- `comment_count` (number, optional): Number of comments to display

**Example:**
```lua
cli.issue_view("PROJ-123", 5)
```

#### `cli.issue_create(args)`

Creates a new issue.

**Parameters:**
- `args` (string, optional): Command-line arguments for issue creation

**Example:**
```lua
cli.issue_create('-tBug -s"Bug title" -b"Description"')
```

#### `cli.issue_transition(issue_key, state, comment, assignee, resolution)`

Transitions an issue to a new state.

**Parameters:**
- `issue_key` (string): Jira issue key
- `state` (string): New state
- `comment` (string, optional): Comment to add during transition
- `assignee` (string, optional): User to assign during transition
- `resolution` (string, optional): Resolution to set during transition

**Example:**
```lua
cli.issue_transition("PROJ-123", "In Progress", "Starting work on this")
```

## Form Module (`jira-nvim.form`)

```lua
local form = require('jira-nvim.form')
```

This module provides interactive form interfaces.

### `form.create_issue()`

Opens the issue creation form.

**Example:**
```lua
form.create_issue()
```

### `form.list_issues()`

Opens the issue list filtering form.

**Example:**
```lua
form.list_issues()
```

### Preset Queries

#### `form.my_issues()`

Lists issues assigned to the current user.

#### `form.my_todo_issues()`

Lists "To Do" issues assigned to the current user.

#### `form.my_in_progress_issues()`

Lists "In Progress" issues assigned to the current user.

#### `form.recent_issues()`

Lists issues created in the last 7 days.

#### `form.unassigned_issues()`

Lists unassigned issues.

#### `form.high_priority_issues()`

Lists high priority issues.

## Form Enhancements Module (`jira-nvim.form_enhancements`)

```lua
local form_enhancements = require('jira-nvim.form_enhancements')
```

This module provides enhanced features for forms.

### `form_enhancements.toggle_markdown_preview(buf, win)`

Toggles markdown preview for a buffer.

**Parameters:**
- `buf` (number): Buffer handle
- `win` (number): Window handle

### `form_enhancements.apply_issue_template(buf, issue_type)`

Applies a template for the specified issue type.

**Parameters:**
- `buf` (number): Buffer handle
- `issue_type` (string): Issue type (e.g., "Bug", "Story")

**Returns:** `boolean` - Success status

### `form_enhancements.setup_autocompletion(buf)`

Sets up autocompletion for a buffer.

**Parameters:**
- `buf` (number): Buffer handle

## Dashboard Module (`jira-nvim.dashboard`)

```lua
local dashboard = require('jira-nvim.dashboard')
```

This module provides dashboard functionality.

### `dashboard.show_dashboard()`

Shows the personalized Jira dashboard.

### `dashboard.show_stats()`

Shows personal Jira statistics.

## Context Module (`jira-nvim.context`)

```lua
local context = require('jira-nvim.context')
```

This module provides context awareness features.

### `context.show_context()`

Shows Jira issues related to the current context.

### `context.detect_issue_key(text)`

Detects Jira issue keys in text.

**Parameters:**
- `text` (string): Text to search for issue keys

**Returns:** `string` or `nil` - Detected issue key

### `context.detect_issue_key_from_branch()`

Detects Jira issue key from the current git branch.

**Returns:** `string` or `nil` - Detected issue key

### `context.go_to_issue_under_cursor()`

Views the Jira issue under the cursor.

### `context.open_issue_under_cursor()`

Opens the Jira issue under the cursor in a browser.

## Git Module (`jira-nvim.git`)

```lua
local git = require('jira-nvim.git')
```

This module provides Git integration features.

### `git.create_branch_for_issue(issue_key, branch_prefix)`

Creates a git branch for a Jira issue.

**Parameters:**
- `issue_key` (string): Jira issue key
- `branch_prefix` (string, optional): Branch prefix (e.g., "feature", "bugfix")

### `git.link_commit_to_issue(commit_hash, issue_key)`

Links a git commit to a Jira issue.

**Parameters:**
- `commit_hash` (string): Git commit hash
- `issue_key` (string): Jira issue key

### `git.show_commit_history()`

Shows git commit history with Jira issue links.

### `git.create_branch_with_prefix()`

Opens a dialog to create a git branch with prefix selection.

### `git.update_issue_with_branch()`

Updates a Jira issue with git branch information.

### `git.install_git_hooks()`

Installs git hooks for Jira integration.

## LSP Module (`jira-nvim.lsp`)

```lua
local lsp = require('jira-nvim.lsp')
```

This module provides LSP/editor integration features.

### `lsp.setup()`

Sets up LSP integration features.

### `lsp.highlight_issue_keys(bufnr)`

Highlights Jira issue keys in a buffer.

**Parameters:**
- `bufnr` (number): Buffer number (0 for current buffer)

## Cache Module (`jira-nvim.cache`)

```lua
local cache = require('jira-nvim.cache')
```

This module provides caching functionality.

### `cache.configure(options)`

Configures the caching system.

**Parameters:**
- `options` (table): Cache configuration options

**Example:**
```lua
cache.configure({
  enabled = true,
  ttl = 300,      -- 5 minutes
  max_size = 100  -- 100 items per cache type
})
```

### `cache.setup(api)`

Sets up API method caching.

**Parameters:**
- `api` (table): API module to wrap with caching

### `cache.show_stats()`

Shows cache statistics.

### `cache.clear(cache_type)`

Clears the cache.

**Parameters:**
- `cache_type` (string, optional): Cache type to clear (nil for all caches)

## Errors Module (`jira-nvim.errors`)

```lua
local errors = require('jira-nvim.errors')
```

This module provides enhanced error handling.

### `errors.setup(api)`

Sets up enhanced error handling.

**Parameters:**
- `api` (table): API module to wrap with error handling

### `errors.show_troubleshooting()`

Shows the troubleshooting guide.

## Utils Module (`jira-nvim.utils`)

```lua
local utils = require('jira-nvim.utils')
```

This module provides utility functions.

### `utils.show_info(message)`

Shows an information message.

**Parameters:**
- `message` (string): Message to show

### `utils.show_warning(message)`

Shows a warning message.

**Parameters:**
- `message` (string): Message to show

### `utils.show_error(message)`

Shows an error message.

**Parameters:**
- `message` (string): Message to show

### `utils.debug(message)`

Logs a debug message.

**Parameters:**
- `message` (string or table): Message to log

## Configuration

### Complete Configuration Options

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
  show_icons = true,                              -- Show visual icons in output
  show_progress = true,                           -- Show progress indicators
  enhanced_formatting = true,                     -- Use enhanced text formatting
  
  -- Colors for different issue types/statuses
  colors = {
    issue_key = 'Identifier',                     -- Highlight group for issue keys
    status = 'Statement',                         -- Highlight group for status
    priority = 'Special',                         -- Highlight group for priority
    issue_type = 'Type',                          -- Highlight group for issue type
    user = 'PreProc'                              -- Highlight group for user names
  },
  
  -- API options
  api_timeout = 10000,                            -- API request timeout in ms
  max_results = 50,                               -- Maximum search results
  max_comments = 10,                              -- Maximum comments to display
  
  -- Integration options
  enable_lsp_integration = false,                 -- Enable LSP features
  enable_git_integration = true,                  -- Enable Git features
  
  -- Caching options
  enable_caching = true,                          -- Enable API caching
  cache_ttl = 300,                                -- Cache TTL in seconds
  cache_size = 100,                               -- Maximum cache items
  
  -- Error handling
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

## Events and Callbacks

jira-nvim doesn't currently provide a formal event system, but you can hook into its functionality by wrapping the module functions.

**Example: Adding custom logging to issue creation**

```lua
-- Store the original function
local original_issue_create = require('jira-nvim.cli').issue_create

-- Override with custom function
require('jira-nvim.cli').issue_create = function(args)
  -- Custom logging
  print("Creating issue with args: " .. tostring(args))
  
  -- Call original function
  original_issue_create(args)
end
```

## Examples

### Custom Dashboard

```lua
local api = require('jira-nvim.api')
local ui = require('jira-nvim.ui')

local function show_custom_dashboard()
  -- Get my assigned issues
  api.search_issues("assignee = currentUser() ORDER BY priority DESC", 10, function(err, results)
    if err then
      utils.show_error("Error loading issues: " .. err)
      return
    end
    
    local lines = {
      "🌟 My Custom Dashboard",
      "====================",
      ""
    }
    
    -- Format the results
    if results and results.issues then
      for _, issue in ipairs(results.issues) do
        table.insert(lines, "• " .. issue.key .. ": " .. issue.fields.summary)
        table.insert(lines, "  Status: " .. issue.fields.status.name .. 
                           ", Priority: " .. issue.fields.priority.name)
        table.insert(lines, "")
      end
    else
      table.insert(lines, "No issues found")
    end
    
    -- Show in UI
    ui.show_output("Custom Dashboard", table.concat(lines, "\n"))
  end)
end
```

### Custom Issue Template

```lua
local form_enhancements = require('jira-nvim.form_enhancements')

-- Add custom template
form_enhancements.issue_templates["Security"] = [[
## Security Impact
- [ ] Authentication
- [ ] Authorization
- [ ] Data Exposure
- [ ] Injection

## Description of Vulnerability


## Steps to Reproduce
1. 
2. 
3. 

## Potential Impact


## Recommended Fix

]]

-- Use it when creating issues
-- Now when Type: Security is selected, pressing <C-t> will apply this template
```

### Custom Keymaps

```lua
vim.keymap.set('n', '<leader>jm', function()
  -- Custom Jira view showing issues modified today
  local jql = "updated >= startOfDay() AND assignee = currentUser()"
  require('jira-nvim.cli').issue_list('-q"' .. jql .. '"')
end, { desc = 'Jira: Modified Today' })
```

## Best Practices

1. **Cache API Responses**: When extending jira-nvim, use the cache module for API calls to improve performance.

   ```lua
   local cache = require('jira-nvim.cache')
   local api = require('jira-nvim.api')
   
   cache.setup(api)
   ```

2. **Handle Errors Gracefully**: Always provide user-friendly error messages.

   ```lua
   local utils = require('jira-nvim.utils')
   
   api.get_issue("PROJ-123", function(err, issue)
     if err then
       utils.show_error("Failed to load issue: " .. err)
       return
     end
     
     -- Process issue
   end)
   ```

3. **Use Asynchronous Operations**: Never block Neovim with synchronous API calls.

4. **Provide User Feedback**: Always show loading and completion messages.

   ```lua
   utils.show_info("Loading issues...")
   
   -- After operation completes:
   utils.show_info("Issues loaded successfully")
   ```

5. **Follow Neovim UI Patterns**: Use floating windows, highlights, and other Neovim UI conventions.

---

This API reference is a living document and will be updated as jira-nvim evolves. Please refer to the source code for the most up-to-date implementation details.