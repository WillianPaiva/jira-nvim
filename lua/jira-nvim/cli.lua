local M = {}

local config = require('jira-nvim.config')
local ui = require('jira-nvim.ui')
local utils = require('jira-nvim.utils')
local user = require('jira-nvim.user')
local api = require('jira-nvim.api')

-- Helper function to show progress and handle API calls
local function execute_api_call(operation_name, api_call, callback)
  -- Check API availability
  if not utils.is_api_available() then
    utils.show_error('Jira API not configured. Please set your Jira credentials first.')
    return
  end
  
  -- Show spinner while waiting for API response
  local spinner = utils.create_spinner('Loading ' .. operation_name)
  
  -- Execute the API call
  api_call(function(err, data)
    spinner.stop()
    callback(err, data)
  end)
end

-- List issues matching JQL or filter
function M.issue_list(args)
  local jql
  local project_filter = false
  
  -- Parse args to handle the CLI argument style for backward compatibility
  if args and args ~= '' then
    if args:match('^%-q') then
      -- Explicit JQL query
      jql = args:match('%-q["]?([^"]+)["]?')
    else
      -- Build JQL from multiple conditions
      local jql_parts = {}
      
      -- Check for assignee flag
      local assignee = args:match('%-a["]?([^"]+)["]?')
      if assignee then
        table.insert(jql_parts, 'assignee = "' .. assignee .. '"')
      end
      
      -- Check for project flag
      local project = args:match('%-p["]?([^"]+)["]?')
      if project then
        project_filter = true
        table.insert(jql_parts, 'project = "' .. project .. '"')
      end
      
      -- Check for status flag
      local status = args:match('%-s["]?([^"]+)["]?')
      if status then
        table.insert(jql_parts, 'status = "' .. status .. '"')
      end
      
      -- Check for priority flag
      local priority = args:match('%-y["]?([^"]+)["]?')
      if priority then
        table.insert(jql_parts, 'priority = "' .. priority .. '"')
      end
      
      -- Check for created flag (e.g., --created -7d)
      local created = args:match('%-%-created%s+([^%s]+)')
      if created then
        table.insert(jql_parts, 'created >= "' .. created .. '"')
      end
      
      -- If we found any conditions, build the JQL
      if #jql_parts > 0 then
        jql = table.concat(jql_parts, ' AND ')
      else
        -- If argument doesn't match expected patterns, use it as JQL directly
        jql = args
      end
    end
  else
    -- Check for default project
    local default_project = config.get('project_key') or config.get('default_project')
    if default_project and default_project ~= '' then
      project_filter = true
      jql = 'project = "' .. default_project .. '"'
    else
      -- Default query: show all issues
      jql = 'project IS NOT EMPTY'
    end
  end
  
  -- Add default ordering if not already specified
  if not jql:match('ORDER BY') then
    jql = jql .. ' ORDER BY updated DESC'
  end
  
  -- Add window title suffix based on query
  local title_suffix = ''
  if project_filter then
    local project_name = jql:match('project = "([^"]+)"')
    if project_name then
      title_suffix = ' - Project: ' .. project_name
    end
  end
  
  execute_api_call('issues', function(callback)
    api.search_issues(jql, config.get('max_results'), callback)
  end, function(err, data)
    if err then
      if err:match("No result found") or err:match("no issues found") then
        utils.show_warning('No issues found matching your criteria. Try adjusting your filters.')
      elseif err:match("Authentication") or err:match("Unauthorized") then
        utils.show_error('Authentication failed. Please check your Jira credentials.')
      else
        utils.show_error('Error listing issues: ' .. err)
      end
      return
    end
    
    local formatted_output = utils.parse_api_response(data, 'issues')
    ui.show_output('Jira Issues' .. title_suffix, formatted_output)
  end)
end

-- View issue details
function M.issue_view(issue_key, show_comments)
  local valid, error_msg = utils.validate_issue_key(issue_key)
  if not valid then
    utils.show_warning(error_msg)
    return
  end
  
  execute_api_call('issue ' .. issue_key, function(callback)
    api.get_issue(issue_key, callback)
  end, function(err, data)
    if err then
      utils.show_error('Error viewing issue: ' .. err)
      return
    end
    
    -- Add to search history
    local search = require('jira-nvim.search')
    search.add_to_history(issue_key)
    
    -- Format the issue data for display
    local formatted_output = utils.parse_api_response(data, 'issue')
    ui.show_output('Issue: ' .. issue_key, formatted_output)
  end)
end

-- Create new issue
function M.issue_create(args)
  -- Parse args for backward compatibility with CLI version
  local project_key = config.get('project_key')
  local issue_type = 'Task'
  local summary = ''
  local description = ''
  
  if args and args ~= '' then
    -- Parse project flag
    local p_match = args:match('%-p["]?([^"]+)["]?')
    if p_match then
      project_key = p_match
    end
    
    -- Parse issue type flag
    local t_match = args:match('%-t["]?([^"]+)["]?')
    if t_match then
      issue_type = t_match
    end
    
    -- Parse summary flag
    local s_match = args:match('%-s["]?([^"]+)["]?')
    if s_match then
      summary = s_match
    end
    
    -- Parse description flag
    local d_match = args:match('%-d["]?([^"]+)["]?')
    if d_match then
      description = d_match
    end
  end
  
  -- If we still don't have required fields, prompt user
  if not project_key or project_key == '' then
    project_key = vim.fn.input('Project key: ')
    if not project_key or project_key == '' then
      utils.show_error('Project key is required')
      return
    end
  end
  
  if not summary or summary == '' then
    summary = vim.fn.input('Issue summary: ')
    if not summary or summary == '' then
      utils.show_error('Summary is required')
      return
    end
  end
  
  execute_api_call('new issue', function(callback)
    api.create_issue(project_key, issue_type, summary, description, nil, callback)
  end, function(err, data)
    if err then
      utils.show_error('Error creating issue: ' .. err)
      return
    end
    
    utils.show_info('Issue created: ' .. data.key)
    
    -- Get the newly created issue to display it
    M.issue_view(data.key)
  end)
end

-- List sprints
function M.sprint_list(args)
  -- Parse args for board ID
  local board_id
  if args and args ~= '' then
    -- Extract board ID from arguments if provided
    local id_match = args:match('%-b["]?([^"]+)["]?')
    if id_match then
      board_id = id_match
    end
  end
  
  -- If no board ID specified, check for default board
  if not board_id then
    board_id = config.get('default_board')
  end
  
  -- If still no board ID, get a list of boards
  if not board_id then
    execute_api_call('boards', function(callback)
      api.get_boards(callback)
    end, function(err, data)
      if err then
        utils.show_error('Error getting boards: ' .. err)
        return
      end
      
      -- If only one board, use it directly
      if #data == 1 then
        local board = data[1]
        execute_api_call('sprints', function(callback)
          api.get_sprints(board.id, callback)
        end, function(err, sprint_data)
          if err then
            utils.show_error('Error listing sprints: ' .. err)
            return
          end
          
          local formatted_output = utils.parse_api_response(sprint_data, 'sprints')
          ui.show_output('Jira Sprints for Board ' .. board.name, formatted_output)
        end)
      else
        -- Display boards for selection
        local formatted_output = utils.parse_api_response(data, 'boards')
        ui.show_output('Jira Boards (Select one to view sprints)', formatted_output)
      end
    end)
  else
    -- If board ID was provided, get sprints directly
    execute_api_call('sprints', function(callback)
      api.get_sprints(board_id, callback)
    end, function(err, data)
      if err then
        utils.show_error('Error listing sprints: ' .. err)
        return
      end
      
      local formatted_output = utils.parse_api_response(data, 'sprints')
      ui.show_output('Jira Sprints', formatted_output)
    end)
  end
end

-- List epics
function M.epic_list(args)
  -- Parse args for board ID
  local board_id
  if args and args ~= '' then
    -- Extract board ID from arguments if provided
    local id_match = args:match('%-b["]?([^"]+)["]?')
    if id_match then
      board_id = id_match
    end
  end
  
  -- If no board ID specified, check for default board
  if not board_id then
    board_id = config.get('default_board')
  end
  
  -- If still no board ID, get a list of boards
  if not board_id then
    execute_api_call('boards', function(callback)
      api.get_boards(callback)
    end, function(err, data)
      if err then
        utils.show_error('Error getting boards: ' .. err)
        return
      end
      
      -- If only one board, use it directly
      if #data == 1 then
        local board = data[1]
        execute_api_call('epics', function(callback)
          api.get_epics(board.id, callback)
        end, function(err, epic_data)
          if err then
            utils.show_error('Error listing epics: ' .. err)
            return
          end
          
          local formatted_output = utils.parse_api_response(epic_data, 'epics')
          ui.show_output('Jira Epics for Board ' .. board.name, formatted_output)
        end)
      else
        -- Display boards for selection
        local formatted_output = utils.parse_api_response(data, 'boards')
        ui.show_output('Jira Boards (Select one to view epics)', formatted_output)
      end
    end)
  else
    -- If board ID was provided, get epics directly
    execute_api_call('epics', function(callback)
      api.get_epics(board_id, callback)
    end, function(err, data)
      if err then
        utils.show_error('Error listing epics: ' .. err)
        return
      end
      
      local formatted_output = utils.parse_api_response(data, 'epics')
      ui.show_output('Jira Epics', formatted_output)
    end)
  end
end

-- Open issue or project in browser
function M.open(issue_key)
  if not issue_key or issue_key == '' then
    -- Open the Jira homepage
    local jira_url = config.get('jira_url')
    if jira_url then
      utils.open_in_browser(jira_url)
      utils.show_info('Opened Jira homepage in browser')
    else
      utils.show_error('Jira URL not configured')
    end
    return
  end
  
  local valid, _ = utils.validate_issue_key(issue_key)
  if not valid then
    -- Might be a project key, try to open project
    utils.open_in_browser(config.get('jira_url') .. '/projects/' .. issue_key)
    utils.show_info('Opened project ' .. issue_key .. ' in browser')
    return
  end
  
  -- It's an issue key, get the browse URL
  local browse_url = api.get_browse_url(issue_key)
  if browse_url then
    utils.open_in_browser(browse_url)
    utils.show_info('Opened issue ' .. issue_key .. ' in browser')
  else
    utils.show_error('Could not open issue ' .. issue_key .. ' - check Jira URL configuration')
  end
end

-- List projects
function M.project_list()
  execute_api_call('projects', function(callback)
    api.get_projects(callback)
  end, function(err, data)
    if err then
      utils.show_error('Error listing projects: ' .. err)
      return
    end
    
    local formatted_output = utils.parse_api_response(data, 'projects')
    ui.show_output('Jira Projects', formatted_output)
  end)
end

-- List boards
function M.board_list(project_key)
  -- If project key provided, list boards for that project
  if project_key and project_key ~= '' then
    execute_api_call('project boards', function(callback)
      api.get_project_boards(project_key, callback)
    end, function(err, data)
      if err then
        utils.show_error('Error listing project boards: ' .. err)
        return
      end
      
      local formatted_output = utils.parse_api_response(data, 'boards')
      ui.show_output('Jira Boards for Project ' .. project_key, formatted_output)
    end)
  else
    -- Otherwise list all boards
    execute_api_call('boards', function(callback)
      api.get_boards(callback)
    end, function(err, data)
      if err then
        utils.show_error('Error listing boards: ' .. err)
        return
      end
      
      local formatted_output = utils.parse_api_response(data, 'boards')
      ui.show_output('Jira Boards', formatted_output)
    end)
  end
end

-- List boards for the default project
function M.project_boards()
  local project_key = config.get('project_key') or config.get('default_project')
  
  if not project_key or project_key == '' then
    utils.show_error('No default project configured. Please set a project in the configuration.')
    return
  end
  
  M.board_list(project_key)
end

-- Get available transitions for an issue
function M.get_available_transitions(issue_key, callback)
  local valid, error_msg = utils.validate_issue_key(issue_key)
  if not valid then
    callback(error_msg, nil)
    return
  end
  
  execute_api_call('transitions', function(cb)
    api.get_transitions(issue_key, cb)
  end, function(err, data)
    if err then
      callback(err, nil)
      return
    end
    
    if not data or not data.transitions then
      callback('No transitions available for issue ' .. issue_key, nil)
      return
    end
    
    local transitions = {}
    for _, transition in ipairs(data.transitions) do
      table.insert(transitions, transition.name)
    end
    
    callback(nil, transitions)
  end)
end

-- Transition issue to a new state
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
  
  -- First, get available transitions to find the correct transition ID
  execute_api_call('transitions', function(callback)
    api.get_transitions(issue_key, callback)
  end, function(err, data)
    if err then
      utils.show_error('Error getting transitions: ' .. err)
      return
    end
    
    if not data or not data.transitions then
      utils.show_error('No transitions available for issue ' .. issue_key)
      return
    end
    
    -- Find the transition that matches the requested state
    local transition_id
    for _, transition in ipairs(data.transitions) do
      if transition.name:lower() == state:lower() then
        transition_id = transition.id
        break
      end
    end
    
    if not transition_id then
      -- Show available transitions
      local available = {}
      for _, t in ipairs(data.transitions) do
        table.insert(available, t.name)
      end
      utils.show_error('Invalid state: "' .. state .. '". Available states: ' .. table.concat(available, ', '))
      return
    end
    
    -- Handle fields for the transition
    local fields = {}
    if resolution and resolution ~= '' then
      fields.resolution = { name = resolution }
    end
    
    -- Perform the transition
    execute_api_call('transition', function(callback)
      api.transition_issue(issue_key, transition_id, fields, comment, callback)
    end, function(err, result)
      if err then
        utils.show_error('Error transitioning issue: ' .. err)
        return
      end
      
      utils.show_info('Issue ' .. issue_key .. ' transitioned to "' .. state .. '"')
      
      -- Handle assignee update if provided
      if assignee and assignee ~= '' then
        if assignee:lower() == 'me' then
          -- Get current user first
          api.get_current_user(function(err, user_data)
            if err then
              utils.show_error('Error getting current user: ' .. err)
              return
            end
            
            M.issue_assign(issue_key, user_data.accountId)
          end)
        else
          -- Check if it's an unassign command
          if assignee:lower() == 'unassign' or assignee:lower() == 'none' then
            M.issue_assign(issue_key, 'none')
          else
            -- Try to assign directly by username/email
            M.issue_assign(issue_key, assignee)
          end
        end
      end
      
      -- Refresh the issue view
      M.issue_view(issue_key)
    end)
  end)
end

-- Add a comment to an issue
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
  
  execute_api_call('comment', function(callback)
    api.add_comment(issue_key, comment_body, callback)
  end, function(err, data)
    if err then
      utils.show_error('Error adding comment: ' .. err)
      return
    end
    
    utils.show_info('Comment added to issue ' .. issue_key)
    
    -- Refresh the issue view to show the new comment
    M.issue_view(issue_key)
  end)
end

-- Add a comment from buffer content
function M.issue_comment_add_from_buffer(issue_key, buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local comment_body = table.concat(lines, '\n')
  
  if comment_body:match('^%s*$') then
    utils.show_warning('Comment cannot be empty')
    return
  end
  
  M.issue_comment_add(issue_key, comment_body)
end

-- Assign issue to user
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
  
  local account_id = nil
  
  -- Handle special cases
  if assignee:lower() == 'unassign' or assignee:lower() == 'none' then
    account_id = 'none'
    perform_assign()
  elseif assignee:lower() == 'me' or assignee:lower() == 'self' then
    -- Get current user first
    execute_api_call('current user', function(callback)
      api.get_current_user(callback)
    end, function(err, data)
      if err then
        utils.show_error('Error getting current user: ' .. err)
        return
      end
      
      account_id = data.accountId
      perform_assign()
    end)
  else
    -- Try to find user by name or email
    execute_api_call('user search', function(callback)
      api.find_users(assignee, callback)
    end, function(err, data)
      if err then
        utils.show_error('Error finding user: ' .. err)
        return
      end
      
      if #data == 0 then
        utils.show_error('No user found with name/email: ' .. assignee)
        return
      end
      
      account_id = data[1].accountId
      perform_assign()
    end)
  end
  
  function perform_assign()
    execute_api_call('assign', function(callback)
      api.assign_issue(issue_key, account_id, callback)
    end, function(err, data)
      if err then
        utils.show_error('Error assigning issue: ' .. err)
        return
      end
      
      local display_name = assignee
      if account_id == 'none' then
        display_name = 'unassigned'
      end
      
      utils.show_info('Issue ' .. issue_key .. ' assigned to ' .. display_name)
      
      -- Refresh the issue view
      M.issue_view(issue_key)
    end)
  end
end

-- Add watcher to issue
function M.issue_watch(issue_key, watcher)
  local valid, error_msg = utils.validate_issue_key(issue_key)
  if not valid then
    utils.show_warning(error_msg)
    return
  end
  
  local account_id = nil
  
  -- Handle special cases
  if not watcher or watcher == '' or watcher:lower() == 'me' or watcher:lower() == 'self' then
    -- Get current user first
    execute_api_call('current user', function(callback)
      api.get_current_user(callback)
    end, function(err, data)
      if err then
        utils.show_error('Error getting current user: ' .. err)
        return
      end
      
      account_id = data.accountId
      perform_watch()
    end)
  else
    -- Try to find user by name or email
    execute_api_call('user search', function(callback)
      api.find_users(watcher, callback)
    end, function(err, data)
      if err then
        utils.show_error('Error finding user: ' .. err)
        return
      end
      
      if #data == 0 then
        utils.show_error('No user found with name/email: ' .. watcher)
        return
      end
      
      account_id = data[1].accountId
      perform_watch()
    end)
  end
  
  function perform_watch()
    execute_api_call('watch', function(callback)
      api.add_watcher(issue_key, account_id, callback)
    end, function(err, data)
      if err then
        utils.show_error('Error adding watcher: ' .. err)
        return
      end
      
      utils.show_info('Added watcher to issue ' .. issue_key)
      
      -- Refresh the issue view
      M.issue_view(issue_key)
    end)
  end
end

-- Get current user
function M.get_current_user(callback)
  execute_api_call('current user', function(cb)
    api.get_current_user(cb)
  end, callback)
end

-- Get current active sprint from default board
function M.current_sprint()
  local board_id = config.get('default_board')
  
  if not board_id then
    utils.show_error('No default board configured. Please set a default board in the configuration.')
    return
  end
  
  execute_api_call('active sprint', function(callback)
    api.get_active_sprint(board_id, callback)
  end, function(err, data)
    if err then
      utils.show_error('Error getting active sprint: ' .. err)
      return
    end
    
    -- Check if we have any active sprints
    if not data.values or #data.values == 0 then
      utils.show_warning('No active sprint found for the default board.')
      return
    end
    
    -- Get issues from the active sprint
    local sprint = data.values[1] -- Use the first active sprint if multiple
    local jql = 'sprint = ' .. sprint.id
    
    -- Add project filter if we have a default project
    local default_project = config.get('project_key') or config.get('default_project')
    if default_project and default_project ~= '' then
      jql = jql .. ' AND project = "' .. default_project .. '"'
    end
    
    -- Add ordering
    jql = jql .. ' ORDER BY status ASC, updated DESC'
    
    -- Show title with sprint name
    local title = 'Current Sprint: ' .. sprint.name
    if sprint.goal and sprint.goal ~= '' then
      title = title .. ' - ' .. sprint.goal
    end
    
    -- Search for issues
    execute_api_call('sprint issues', function(callback)
      api.search_issues(jql, config.get('max_results'), callback)
    end, function(err, issues_data)
      if err then
        utils.show_error('Error getting sprint issues: ' .. err)
        return
      end
      
      local formatted_output = utils.parse_api_response(issues_data, 'issues')
      ui.show_output(title, formatted_output)
    end)
  end)
end

return M