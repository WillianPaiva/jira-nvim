local M = {}
local config = require('jira-nvim.config')

local function trim(s)
  return s:match('^%s*(.-)%s*$')
end

-- Check if API is configured correctly
function M.is_api_available()
  return config.has_credentials()
end

-- Legacy check for CLI tool, kept for backward compatibility but always returns false
function M.is_jira_available()
  return false
end

-- Validate Jira issue key format
function M.validate_issue_key(key)
  if not key or key == '' then
    return false, 'Issue key cannot be empty'
  end

  if not key:match('^[A-Z]+-[0-9]+$') then
    return false, 'Invalid issue key format. Expected format: PROJECT-123'
  end

  return true, nil
end

-- Format JQL query with proper escaping
function M.format_jql(query)
  -- If already a JQL query, return as is
  if query:match('=') or query:match('~') or query:match('AND') or query:match('OR') then
    return query
  end

  -- If it's an issue key, construct a JQL query
  if query:match('^[A-Z]+-[0-9]+$') then
    return 'issuekey = "' .. query .. '"'
  end

  -- Otherwise, assume it's a text search query
  return 'summary ~ "' .. query:gsub('"', '\\"') .. '" OR description ~ "' .. query:gsub('"', '\\"') .. '"'
end

-- Parse structured API response into displayable format
function M.parse_api_response(response, format)
  if not response then
    return {}
  end

  if format == 'issue' and response.key then
    -- Single issue response
    local api = require('jira-nvim.api')
    return api.format_issue_for_display(response)
  elseif format == 'issues' and response.issues then
    -- Issue search response
    local api = require('jira-nvim.api')
    return api.format_search_results(response)
  elseif format == 'projects' and type(response) == 'table' then
    -- Projects list
    local result = { 'Available Projects:', string.rep('-', 40), '' }

    for _, project in ipairs(response) do
      table.insert(result, project.key .. ' - ' .. project.name)
    end

    return table.concat(result, '\n')
  elseif format == 'boards' and type(response) == 'table' then
    -- Boards list
    local result = { 'Available Boards:', string.rep('-', 40), '' }

    for _, board in ipairs(response) do
      table.insert(result, board.id .. ' - ' .. board.name .. ' (' .. board.type .. ')')
    end

    return table.concat(result, '\n')
  elseif format == 'sprints' and type(response) == 'table' then
    -- Sprints list
    local result = { 'Available Sprints:', string.rep('-', 40), '' }

    for _, sprint in ipairs(response) do
      local status = sprint.state or 'unknown'
      table.insert(result, sprint.id .. ' - ' .. sprint.name .. ' (' .. status .. ')')
    end

    return table.concat(result, '\n')
  elseif format == 'epics' and type(response) == 'table' then
    -- Epics list
    local result = { 'Available Epics:', string.rep('-', 40), '' }

    for _, epic in ipairs(response) do
      table.insert(result, epic.key .. ' - ' .. epic.name)
    end

    return table.concat(result, '\n')
  else
    -- Generic JSON response
    return vim.inspect(response)
  end
end

-- Parse CLI output (legacy, kept for backward compatibility)
function M.parse_jira_output(output)
  if not output or output == '' then
    return {}
  end

  local lines = vim.split(output, '\n', { plain = true })
  local parsed = {}

  for _, line in ipairs(lines) do
    if line and trim(line) ~= '' then
      table.insert(parsed, line)
    end
  end

  return parsed
end

-- Sanitize arguments (legacy, kept for backward compatibility)
function M.sanitize_args(args)
  if not args then
    return ''
  end

  local sanitized = args:gsub('[;&|`$()]', '')
  return sanitized
end

-- Open URL in browser
function M.open_in_browser(url)
  -- Determine OS for correct command
  local open_cmd
  if vim.fn.has('mac') == 1 then
    open_cmd = 'open'
  elseif vim.fn.has('unix') == 1 then
    open_cmd = 'xdg-open'
  elseif vim.fn.has('win32') == 1 then
    open_cmd = 'start ""'
  else
    M.show_error('Unsupported OS for opening URL')
    return false
  end

  -- Execute the command
  local cmd = open_cmd .. ' "' .. url .. '"'
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    M.show_error('Failed to open URL: ' .. result)
    return false
  end

  return true
end

-- Create a spinner for async operations
function M.create_spinner(message)
  local frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
  local frame_idx = 1

  -- Only show the first message, then update status line
  local status_message = message
  M.show_info(status_message .. ' ' .. frames[1])

  -- Use a single notification that updates
  local timer = vim.fn.timer_start(100, function()
    vim.cmd('echohl MoreMsg')
    vim.cmd('echo "' .. status_message .. ' ' .. frames[frame_idx] .. '"')
    vim.cmd('echohl None')
    frame_idx = frame_idx % #frames + 1
  end, { ['repeat'] = -1 })

  return {
    stop = function(success_msg, error_msg)
      vim.fn.timer_stop(timer)
      vim.cmd('echo ""') -- Clear the echo line
      if success_msg then
        M.show_info(success_msg)
      elseif error_msg then
        M.show_error(error_msg)
      end
    end,
  }
end

function M.show_error(message)
  -- Use LazyVim's notification system if available
  local has_lazyvim, LazyVim = pcall(require, 'lazyvim.util')
  if has_lazyvim and LazyVim.error then
    LazyVim.error(message, { title = 'Jira' })
  else
    vim.notify('Jira Error: ' .. message, vim.log.levels.ERROR)
  end
end

function M.show_info(message, opts)
  opts = opts or {}
  -- If searching, don't show notifications
  if opts.searching then
    return
  end

  local has_lazyvim, LazyVim = pcall(require, 'lazyvim.util')
  if has_lazyvim and LazyVim.info then
    LazyVim.info(message, { title = 'Jira' })
  else
    vim.notify('Jira: ' .. message, vim.log.levels.INFO)
  end
end

function M.show_warning(message)
  local has_lazyvim, LazyVim = pcall(require, 'lazyvim.util')
  if has_lazyvim and LazyVim.warn then
    LazyVim.warn(message, { title = 'Jira' })
  else
    vim.notify('Jira Warning: ' .. message, vim.log.levels.WARN)
  end
end

return M
