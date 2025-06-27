local M = {}

local config = require('jira-nvim.config')
local ui = require('jira-nvim.ui')
local utils = require('jira-nvim.utils')
local user = require('jira-nvim.user')

local function execute_jira_cmd(cmd, args, callback, show_progress)
  if not utils.is_jira_available() then
    utils.show_error('Jira CLI not found. Please install jira-cli first.')
    return
  end
  
  local jira_cmd = config.get('jira_cmd')
  local sanitized_args = utils.sanitize_args(args or '')
  local expanded_args = user.expand_user_patterns(sanitized_args)
  local full_cmd = string.format('%s %s %s', jira_cmd, cmd, expanded_args)
  
  -- Show progress indicator if requested
  local progress_timer
  if show_progress ~= false then
    local frames = {'⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'}
    local frame_idx = 1
    progress_timer = vim.fn.timer_start(100, function()
      utils.show_info('Loading ' .. frames[frame_idx] .. ' ' .. cmd:gsub('issue ', ''))
      frame_idx = frame_idx % #frames + 1
    end, { ['repeat'] = -1 })
  end
  
  vim.fn.jobstart(full_cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if progress_timer then
        vim.fn.timer_stop(progress_timer)
      end
      if callback then
        local output = table.concat(data, '\n')
        callback(nil, output)
      end
    end,
    on_stderr = function(_, data)
      if progress_timer then
        vim.fn.timer_stop(progress_timer)
      end
      if callback then
        local error_msg = table.concat(data, '\n')
        if error_msg and error_msg:match("^%s*(.-)%s*$") ~= '' then
          callback(error_msg, nil)
        end
      end
    end,
    on_exit = function(_, code)
      if progress_timer then
        vim.fn.timer_stop(progress_timer)
      end
      if code ~= 0 and callback then
        callback('Command failed with exit code: ' .. code, nil)
      end
    end
  })
end

function M.issue_list(args)
  local cmd_args = args and args ~= '' and args or '-q"project IS NOT EMPTY"'
  execute_jira_cmd('issue list', cmd_args, function(err, output)
    if err then
      if err:match("No result found for given query") then
        utils.show_warning('No issues found matching your criteria. Try adjusting your filters or use JQL: "project IS NOT EMPTY" to search all projects.')
      else
        utils.show_error('Error listing issues: ' .. err)
      end
      return
    end
    ui.show_output('Jira Issues', output)
  end)
end

function M.issue_view(issue_key, show_comments)
  local valid, error_msg = utils.validate_issue_key(issue_key)
  if not valid then
    utils.show_warning(error_msg)
    return
  end
  
  local args = issue_key
  if show_comments then
    args = args .. ' --comments ' .. tostring(show_comments)
  end
  
  execute_jira_cmd('issue view', args, function(err, output)
    if err then
      utils.show_error('Error viewing issue: ' .. err)
      return
    end
    
    -- Add to search history
    local search = require('jira-nvim.search')
    search.add_to_history(issue_key)
    
    ui.show_output('Issue: ' .. issue_key, output)
  end)
end

function M.issue_create(args)
  execute_jira_cmd('issue create', args, function(err, output)
    if err then
      utils.show_error('Error creating issue: ' .. err)
      return
    end
    utils.show_info('Issue created successfully')
    if output and output ~= '' then
      ui.show_output('Issue Created', output)
    end
  end)
end

function M.sprint_list(args)
  local cmd_args = args and args or '--table --plain'
  execute_jira_cmd('sprint list', cmd_args, function(err, output)
    if err then
      utils.show_error('Error listing sprints: ' .. err)
      return
    end
    ui.show_output('Jira Sprints', output)
  end)
end

function M.epic_list(args)
  local cmd_args = args and args or '--table --plain'
  execute_jira_cmd('epic list', cmd_args, function(err, output)
    if err then
      utils.show_error('Error listing epics: ' .. err)
      return
    end
    ui.show_output('Jira Epics', output)
  end)
end

function M.open(issue_key)
  local cmd_args = issue_key and issue_key or ''
  execute_jira_cmd('open', cmd_args, function(err, output)
    if err then
      utils.show_error('Error opening: ' .. err)
      return
    end
    utils.show_info('Opened in browser')
  end)
end

function M.project_list()
  execute_jira_cmd('project list', '', function(err, output)
    if err then
      utils.show_error('Error listing projects: ' .. err)
      return
    end
    ui.show_output('Jira Projects', output)
  end)
end

function M.board_list()
  execute_jira_cmd('board list', '', function(err, output)
    if err then
      utils.show_error('Error listing boards: ' .. err)
      return
    end
    ui.show_output('Jira Boards', output)
  end)
end

function M.get_available_transitions(issue_key, callback)
  local valid, error_msg = utils.validate_issue_key(issue_key)
  if not valid then
    callback(error_msg, nil)
    return
  end
  
  -- Try an invalid transition to get the available states from error message
  local args = string.format('"%s" "INVALID_STATE_TO_GET_AVAILABLE_STATES"', issue_key)
  
  execute_jira_cmd('issue move', args, function(err, output)
    if err then
      -- Parse available states from error message
      -- Example: "Available states for issue PROJ-123: 'State1', 'State2', 'State3'"
      local states_match = err:match("Available states for issue [^:]+: (.+)")
      if states_match then
        local states = {}
        -- Extract states from single quotes
        for state in states_match:gmatch("'([^']+)'") do
          table.insert(states, state)
        end
        if #states > 0 then
          callback(nil, states)
          return
        end
      end
      -- If we can't parse the states, fall back to error
      callback(err, nil)
    else
      -- This shouldn't happen with an invalid state, but just in case
      callback('Could not retrieve available transitions', nil)
    end
  end)
end

function M.issue_transition(issue_key, state, comment, assignee, resolution)
  local valid, error_msg = utils.validate_issue_key(issue_key)
  if not valid then
    utils.show_warning(error_msg)
    return
  end
  
  if not state or state == '' then
    utils.show_warning('State is required for issue transition')
    return
  end
  
  local args = string.format('"%s" "%s"', issue_key, state)
  
  if comment and comment ~= '' then
    args = args .. ' --comment "' .. comment .. '"'
  end
  
  if assignee and assignee ~= '' then
    args = args .. ' --assignee "' .. assignee .. '"'
  end
  
  if resolution and resolution ~= '' then
    args = args .. ' --resolution "' .. resolution .. '"'
  end
  
  execute_jira_cmd('issue move', args, function(err, output)
    if err then
      utils.show_error('Error transitioning issue: ' .. err)
      return
    end
    utils.show_info('Issue ' .. issue_key .. ' transitioned to "' .. state .. '"')
    if output and output ~= '' then
      ui.show_output('Issue Transitioned', output)
    end
  end)
end

function M.issue_comment_add(issue_key, comment_body)
  local valid, error_msg = utils.validate_issue_key(issue_key)
  if not valid then
    utils.show_warning(error_msg)
    return
  end
  
  if not comment_body or comment_body:match('^%s*$') then
    utils.show_warning('Comment body is required')
    return
  end
  
  local args = string.format('%s "%s"', issue_key, comment_body:gsub('"', '\\"'))
  
  execute_jira_cmd('issue comment add', args, function(err, output)
    if err then
      utils.show_error('Error adding comment: ' .. err)
      return
    end
    utils.show_info('Comment added to issue ' .. issue_key)
    if output and output ~= '' then
      ui.show_output('Comment Added', output)
    end
  end)
end

function M.issue_comment_add_from_buffer(issue_key, buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local comment_body = table.concat(lines, '\n')
  
  if comment_body:match('^%s*$') then
    utils.show_warning('Comment cannot be empty')
    return
  end
  
  M.issue_comment_add(issue_key, comment_body)
end

function M.issue_assign(issue_key, assignee)
  local valid, error_msg = utils.validate_issue_key(issue_key)
  if not valid then
    utils.show_warning(error_msg)
    return
  end
  
  if not assignee or assignee:match('^%s*$') then
    utils.show_warning('Assignee is required')
    return
  end
  
  -- Handle special cases
  if assignee:lower() == 'me' or assignee:lower() == 'self' then
    assignee = '$(jira me)'
  elseif assignee:lower() == 'unassign' or assignee:lower() == 'none' then
    assignee = 'x'
  elseif assignee:lower() == 'default' then
    assignee = 'default'
  end
  
  local args = string.format('%s "%s"', issue_key, assignee)
  
  execute_jira_cmd('issue assign', args, function(err, output)
    if err then
      utils.show_error('Error assigning issue: ' .. err)
      return
    end
    utils.show_info('Issue ' .. issue_key .. ' assigned to ' .. assignee)
    if output and output ~= '' then
      ui.show_output('Issue Assigned', output)
    end
  end)
end

function M.issue_watch(issue_key, watcher)
  local valid, error_msg = utils.validate_issue_key(issue_key)
  if not valid then
    utils.show_warning(error_msg)
    return
  end
  
  watcher = watcher or '$(jira me)' -- Default to self
  
  -- Handle special cases
  if watcher:lower() == 'me' or watcher:lower() == 'self' then
    watcher = '$(jira me)'
  end
  
  local args = string.format('%s "%s"', issue_key, watcher)
  
  execute_jira_cmd('issue watch', args, function(err, output)
    if err then
      utils.show_error('Error adding watcher: ' .. err)
      return
    end
    utils.show_info('Added ' .. watcher .. ' to watchers for ' .. issue_key)
    if output and output ~= '' then
      ui.show_output('Watcher Added', output)
    end
  end)
end

function M.get_current_user(callback)
  execute_jira_cmd('me', '', callback)
end

return M