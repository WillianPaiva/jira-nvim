local M = {}

local api = require('jira-nvim.api')
local utils = require('jira-nvim.utils')
local config = require('jira-nvim.config')
local ui = require('jira-nvim.ui')

-- Store buffers and windows that have markdown preview enabled
M.preview_buffers = {}

-- Check if markdown preview plugins are available
local has_markdown_preview = (function()
  return pcall(require, 'peek') or 
         pcall(require, 'markdown-preview') or
         pcall(require, 'vim-markdown-preview')
end)()

-- Cached data for autocompletion
local cached_data = {
  users = nil,
  components = {},
  priorities = { "Lowest", "Low", "Medium", "High", "Highest" },
  issue_types = { "Bug", "Task", "Story", "Epic", "Sub-task", "Feature", "Improvement" }
}

-- Function to load components for a project
local function load_components(project_key)
  if not project_key then
    project_key = config.get('project_key')
  end
  
  if not project_key or cached_data.components[project_key] then
    return
  end
  
  api.get_project(project_key, function(err, project)
    if err then
      utils.show_error("Failed to load components: " .. err)
      return
    end
    
    if project and project.components then
      cached_data.components[project_key] = {}
      for _, comp in ipairs(project.components) do
        table.insert(cached_data.components[project_key], comp.name)
      end
    end
  end)
end

-- Function to load users for autocompletion
local function load_users()
  if cached_data.users then
    return
  end
  
  -- Use "~" as a minimal query to avoid empty query errors
  -- This works better with Jira API which requires a query param
  api.find_users("~", function(err, users)
    if err then
      -- Handle error but don't show to user during initialization
      -- This prevents startup error messages
      if vim.g.jira_nvim_debug then
        utils.show_error("Failed to load users: " .. err)
      end
      cached_data.users = {} -- Initialize with empty array to prevent repeated attempts
      return
    end
    
    if users then
      cached_data.users = {}
      for _, user in ipairs(users) do
        if user.displayName then
          table.insert(cached_data.users, {
            name = user.displayName,
            email = user.emailAddress,
            account_id = user.accountId
          })
        end
      end
    end
  end)
end

-- Preload autocomplete data
function M.preload_autocomplete_data()
  load_users()
  local project_key = config.get('project_key')
  if project_key then
    load_components(project_key)
  end
end

-- Setup autocompletion for a buffer
function M.setup_autocompletion(buf)
  -- Check if nvim-cmp is available
  local has_cmp = pcall(require, 'cmp')
  
  if not has_cmp then
    -- Fallback to omnifunc if nvim-cmp is not available
    vim.api.nvim_buf_set_option(buf, 'omnifunc', 'v:lua.require("jira-nvim.form_enhancements").omnifunc')
    return
  end
  
  -- If nvim-cmp is available, register a custom source for Jira fields
  local cmp = require('cmp')
  cmp.register_source('jira_fields', require('jira-nvim.form_enhancements.source'))
  
  -- Configure nvim-cmp for this buffer
  cmp.setup.buffer({
    sources = {
      { name = 'jira_fields' },
      { name = 'buffer' },
    }
  })
end

-- Simple omnifunc implementation for autocompletion
function M.omnifunc(findstart, base)
  -- First phase: find start of the word
  if findstart == 1 then
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    
    -- Find the field we're completing
    local field_pattern = "^(%w+):%s*(.*)$"
    local field, _ = line:match(field_pattern)
    
    if not field then
      return -1
    end
    
    -- Find the start position of what we're completing
    local pos = line:sub(1, col):find("[^,%s]+$")
    return pos and pos - 1 or -1
  end
  
  -- Second phase: find completion matches
  local line = vim.api.nvim_get_current_line()
  local field_pattern = "^(%w+):%s*(.*)$"
  local field, _ = line:match(field_pattern)
  
  if not field then
    return {}
  end
  
  local completions = {}
  
  if field == "Assignee" and cached_data.users then
    for _, user in ipairs(cached_data.users) do
      if user.name:lower():find(base:lower(), 1, true) then
        table.insert(completions, user.name)
      elseif user.email and user.email:lower():find(base:lower(), 1, true) then
        table.insert(completions, user.email)
      end
    end
  elseif field == "Components" then
    local project_key = config.get('project_key')
    if project_key and cached_data.components[project_key] then
      for _, comp in ipairs(cached_data.components[project_key]) do
        if comp:lower():find(base:lower(), 1, true) then
          table.insert(completions, comp)
        end
      end
    end
  elseif field == "Type" then
    for _, type_name in ipairs(cached_data.issue_types) do
      if type_name:lower():find(base:lower(), 1, true) then
        table.insert(completions, type_name)
      end
    end
  elseif field == "Priority" then
    for _, priority in ipairs(cached_data.priorities) do
      if priority:lower():find(base:lower(), 1, true) then
        table.insert(completions, priority)
      end
    end
  end
  
  return completions
end

-- Create a custom source for nvim-cmp
M.source = {}
M.source.new = function()
  return setmetatable({}, { __index = M.source })
end

M.source.get_trigger_characters = function()
  return { ' ', ',' }
end

M.source.complete = function(self, params, callback)
  local line = params.context.cursor_line
  local field_pattern = "^(%w+):%s*(.*)$"
  local field, _ = line:match(field_pattern)
  
  if not field then
    callback({ items = {}, isIncomplete = true })
    return
  end
  
  local items = {}
  
  if field == "Assignee" and cached_data.users then
    for _, user in ipairs(cached_data.users) do
      table.insert(items, {
        label = user.name,
        detail = user.email,
        documentation = "User ID: " .. user.account_id
      })
    end
  elseif field == "Components" then
    local project_key = config.get('project_key')
    if project_key and cached_data.components[project_key] then
      for _, comp in ipairs(cached_data.components[project_key]) do
        table.insert(items, {
          label = comp,
          kind = 5 -- Enum for component
        })
      end
    end
  elseif field == "Type" then
    for _, type_name in ipairs(cached_data.issue_types) do
      table.insert(items, {
        label = type_name,
        kind = 14 -- Enum for type
      })
    end
  elseif field == "Priority" then
    for _, priority in ipairs(cached_data.priorities) do
      table.insert(items, {
        label = priority,
        kind = 11 -- Enum for priority
      })
    end
  end
  
  callback({ items = items, isIncomplete = false })
end

-- Toggle markdown preview for a buffer
function M.toggle_markdown_preview(buf, win)
  -- If we don't have any markdown preview plugin, fallback to our own preview
  if not has_markdown_preview then
    return M.show_internal_markdown_preview(buf, win)
  end
  
  -- Try to use installed plugins
  if pcall(require, 'peek') then
    vim.cmd('PeekToggle')
  elseif pcall(require, 'markdown-preview') then
    vim.cmd('MarkdownPreviewToggle')
  elseif pcall(require, 'vim-markdown-preview') then
    vim.cmd('MarkdownPreview')
  else
    -- Fallback to our own preview
    return M.show_internal_markdown_preview(buf, win)
  end
end

-- Create a simple internal markdown preview
function M.show_internal_markdown_preview(buf, win)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  
  -- Find description section
  local description_start = nil
  for i, line in ipairs(lines) do
    if line:match("^## Description") then
      description_start = i + 1
      break
    end
  end
  
  if not description_start then
    utils.show_warning("No description section found in the form")
    return
  end
  
  -- Get only description lines, skipping comments
  local description_lines = {}
  for i = description_start, #lines do
    if lines[i] and not lines[i]:match("^#") then
      table.insert(description_lines, lines[i])
    end
  end
  
  local description = table.concat(description_lines, '\n')
  
  -- Simple markdown to formatted text conversion
  local formatted = description
  -- Convert headers
  formatted = formatted:gsub("^# (.+)$", "╔═══ %1 ═══╗")
  formatted = formatted:gsub("\n# (.+)$", "\n╔═══ %1 ═══╗")
  formatted = formatted:gsub("^## (.+)$", "┌─── %1 ───┐")
  formatted = formatted:gsub("\n## (.+)$", "\n┌─── %1 ───┐")
  formatted = formatted:gsub("^### (.+)$", "├─ %1 ─┤")
  formatted = formatted:gsub("\n### (.+)$", "\n├─ %1 ─┤")
  
  -- Convert bold and italic
  formatted = formatted:gsub("%*%*(.-)%*%*", "𝐁 %1 𝐁")
  formatted = formatted:gsub("%*(.-)%*", "𝘐 %1 𝘐")
  formatted = formatted:gsub("__(.-)__", "𝐔 %1 𝐔")
  
  -- Convert lists
  formatted = formatted:gsub("^%- (.+)$", "• %1")
  formatted = formatted:gsub("\n%- (.+)$", "\n• %1")
  formatted = formatted:gsub("^%d%. (.+)$", "➊ %1")
  formatted = formatted:gsub("\n%d%. (.+)$", "\n➊ %1")
  
  -- Show the preview window
  local preview_buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.4)
  local height = math.floor(vim.o.lines * 0.6)
  
  -- Position the preview to the right of the current window
  local win_width = vim.api.nvim_win_get_width(win)
  local win_pos = vim.api.nvim_win_get_position(win)
  
  local preview_win = vim.api.nvim_open_win(preview_buf, false, {
    relative = 'editor',
    width = width,
    height = height,
    col = win_pos[2] + win_width + 2,
    row = win_pos[1],
    style = 'minimal',
    border = 'rounded',
    title = ' Markdown Preview ',
    title_pos = 'center'
  })
  
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, vim.split(formatted, '\n', true))
  vim.api.nvim_buf_set_option(preview_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(preview_buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(preview_buf, 'modifiable', false)
  
  -- Store buffer and window for later closing
  M.preview_buffers[buf] = {
    preview_buf = preview_buf,
    preview_win = preview_win
  }
  
  -- Add buffer close handler
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    once = true,
    callback = function()
      if M.preview_buffers[buf] and vim.api.nvim_win_is_valid(M.preview_buffers[buf].preview_win) then
        vim.api.nvim_win_close(M.preview_buffers[buf].preview_win, true)
        M.preview_buffers[buf] = nil
      end
    end
  })
  
  -- Set up auto-update for the preview
  vim.api.nvim_create_autocmd("TextChanged", {
    buffer = buf,
    callback = function()
      if M.preview_buffers[buf] and vim.api.nvim_win_is_valid(M.preview_buffers[buf].preview_win) then
        M.update_markdown_preview(buf)
      end
    end
  })
  
  vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = buf,
    callback = function()
      if M.preview_buffers[buf] and vim.api.nvim_win_is_valid(M.preview_buffers[buf].preview_win) then
        M.update_markdown_preview(buf)
      end
    end
  })
  
  return preview_buf, preview_win
end

-- Update the markdown preview for a buffer
function M.update_markdown_preview(buf)
  if not M.preview_buffers[buf] then return end
  
  local preview_buf = M.preview_buffers[buf].preview_buf
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  
  -- Find description section
  local description_start = nil
  for i, line in ipairs(lines) do
    if line:match("^## Description") then
      description_start = i + 1
      break
    end
  end
  
  if not description_start then
    return
  end
  
  -- Get only description lines, skipping comments
  local description_lines = {}
  for i = description_start, #lines do
    if lines[i] and not lines[i]:match("^#") then
      table.insert(description_lines, lines[i])
    end
  end
  
  local description = table.concat(description_lines, '\n')
  
  -- Simple markdown to formatted text conversion
  local formatted = description
  -- Convert headers
  formatted = formatted:gsub("^# (.+)$", "╔═══ %1 ═══╗")
  formatted = formatted:gsub("\n# (.+)$", "\n╔═══ %1 ═══╗")
  formatted = formatted:gsub("^## (.+)$", "┌─── %1 ───┐")
  formatted = formatted:gsub("\n## (.+)$", "\n┌─── %1 ───┐")
  formatted = formatted:gsub("^### (.+)$", "├─ %1 ─┤")
  formatted = formatted:gsub("\n### (.+)$", "\n├─ %1 ─┤")
  
  -- Convert bold and italic
  formatted = formatted:gsub("%*%*(.-)%*%*", "𝐁 %1 𝐁")
  formatted = formatted:gsub("%*(.-)%*", "𝘐 %1 𝘐")
  formatted = formatted:gsub("__(.-)__", "𝐔 %1 𝐔")
  
  -- Convert lists
  formatted = formatted:gsub("^%- (.+)$", "• %1")
  formatted = formatted:gsub("\n%- (.+)$", "\n• %1")
  formatted = formatted:gsub("^%d%. (.+)$", "➊ %1")
  formatted = formatted:gsub("\n%d%. (.+)$", "\n➊ %1")
  
  vim.api.nvim_buf_set_option(preview_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, vim.split(formatted, '\n', true))
  vim.api.nvim_buf_set_option(preview_buf, 'modifiable', false)
end

-- Issue type templates
M.issue_templates = {
  Bug = [[
## Steps to Reproduce
1. 
2. 
3. 

## Expected Behavior


## Actual Behavior


## Screenshots/Logs


## Environment
- Version: 
- OS: 
- Browser/Device: 
]],

  Task = [[
## Objective


## Requirements


## Acceptance Criteria
- [ ] 
- [ ] 
- [ ] 

## Additional Notes

]],

  Story = [[
## User Story
As a [type of user],
I want [goal],
So that [benefit].

## Acceptance Criteria
- [ ] 
- [ ] 
- [ ] 

## Technical Notes


## Dependencies

]],

  Epic = [[
## Epic Description


## Goals & Objectives


## Scope
- In scope:
  - 
  - 

- Out of scope:
  - 
  - 

## Related Stories/Tasks
- 
- 

]],

  ["Sub-task"] = [[
## Objective


## Parent Issue


## Required Steps
1. 
2. 
3. 

]],

  Feature = [[
## Feature Description


## Business Value


## User Experience


## Technical Requirements


## Acceptance Criteria
- [ ] 
- [ ] 
- [ ] 

]]
}

-- Apply template based on issue type
function M.apply_issue_template(buf, issue_type)
  local template = M.issue_templates[issue_type]
  if not template then
    return false
  end
  
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  
  -- Find description section
  local description_start_line = nil
  local description_end_line = nil
  
  for i, line in ipairs(lines) do
    if line:match("^## Description") then
      description_start_line = i
    elseif description_start_line and line:match("^#") and not line:match("^# Write your") then
      description_end_line = i - 1
      break
    end
  end
  
  if not description_start_line then
    return false
  end
  
  if not description_end_line then
    description_end_line = #lines
  end
  
  -- Replace the description content
  local new_lines = {}
  
  -- Keep everything before description
  for i = 1, description_start_line do
    table.insert(new_lines, lines[i])
  end
  
  -- Add "# Write your" line if it exists
  local has_write_line = false
  for i = description_start_line + 1, description_end_line do
    if lines[i]:match("^# Write your") then
      table.insert(new_lines, lines[i])
      has_write_line = true
      break
    end
  end
  
  if not has_write_line then
    table.insert(new_lines, "# Write your issue description below this line")
  end
  
  -- Add template
  for _, line in ipairs(vim.split(template, '\n', true)) do
    table.insert(new_lines, line)
  end
  
  -- Keep everything after description
  if description_end_line < #lines then
    for i = description_end_line + 1, #lines do
      table.insert(new_lines, lines[i])
    end
  end
  
  -- Update buffer
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
  return true
end

-- Initialize the module
function M.init()
  -- Preload autocomplete data when module is initialized
  M.preload_autocomplete_data()
end

return M