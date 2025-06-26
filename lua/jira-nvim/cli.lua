local M = {}

local config = require('jira-nvim.config')
local ui = require('jira-nvim.ui')
local utils = require('jira-nvim.utils')

local function execute_jira_cmd(cmd, args, callback)
  if not utils.is_jira_available() then
    utils.show_error('Jira CLI not found. Please install jira-cli first.')
    return
  end
  
  local jira_cmd = config.get('jira_cmd')
  local sanitized_args = utils.sanitize_args(args or '')
  local full_cmd = string.format('%s %s %s', jira_cmd, cmd, sanitized_args)
  
  vim.fn.jobstart(full_cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if callback then
        local output = table.concat(data, '\n')
        callback(nil, output)
      end
    end,
    on_stderr = function(_, data)
      if callback then
        local error_msg = table.concat(data, '\n')
        if error_msg and error_msg:match("^%s*(.-)%s*$") ~= '' then
          callback(error_msg, nil)
        end
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 and callback then
        callback('Command failed with exit code: ' .. code, nil)
      end
    end
  })
end

function M.issue_list(args)
  local cmd_args = args and args or '--plain'
  execute_jira_cmd('issue list', cmd_args, function(err, output)
    if err then
      utils.show_error('Error listing issues: ' .. err)
      return
    end
    ui.show_output('Jira Issues', output)
  end)
end

function M.issue_view(issue_key)
  local valid, error_msg = utils.validate_issue_key(issue_key)
  if not valid then
    utils.show_warning(error_msg)
    return
  end
  
  execute_jira_cmd('issue view', issue_key, function(err, output)
    if err then
      utils.show_error('Error viewing issue: ' .. err)
      return
    end
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
  execute_jira_cmd('project list', '--plain', function(err, output)
    if err then
      utils.show_error('Error listing projects: ' .. err)
      return
    end
    ui.show_output('Jira Projects', output)
  end)
end

function M.board_list()
  execute_jira_cmd('board list', '--plain', function(err, output)
    if err then
      utils.show_error('Error listing boards: ' .. err)
      return
    end
    ui.show_output('Jira Boards', output)
  end)
end

return M