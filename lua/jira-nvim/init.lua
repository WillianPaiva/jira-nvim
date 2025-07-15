local M = {}

local config = require('jira-nvim.config')
local cli = require('jira-nvim.cli')
local ui = require('jira-nvim.ui')
local form = require('jira-nvim.form')
local user = require('jira-nvim.user')
local search = require('jira-nvim.search')
local api = require('jira-nvim.api')
local utils = require('jira-nvim.utils')

-- Check if LazyVim is available for better integration
local has_lazyvim = pcall(require, "lazyvim.util")

function M.setup(opts)
  config.setup(opts or {})
  
  -- Initialize user cache
  user.init()

  -- Register Setup command to configure credentials
  vim.api.nvim_create_user_command('JiraSetup', function()
    -- Run configuration setup interactively
    config.setup({force_setup = true})
    
    -- Test the API connection
    utils.show_info('Testing Jira API connection...')
    api.get_current_user(function(err, data)
      if err then
        utils.show_error('Connection failed: ' .. err)
      else
        utils.show_info('Connection successful! Connected as: ' .. data.displayName)
        
        -- Ask about setting default board
        local project_key = config.get('project_key') or config.get('default_project')
        if project_key and project_key ~= '' then
          vim.defer_fn(function()
            local want_board = vim.fn.input({
              prompt = "\nDo you want to setup a default board for project " .. project_key .. "? (y/n): "
            })
            
            if want_board:lower() == 'y' then
              vim.defer_fn(function()
                utils.show_info('Loading boards for project ' .. project_key)
                
                api.get_project_boards(project_key, function(err, boards)
                  if err then
                    utils.show_error('Error loading project boards: ' .. err)
                    return
                  end
                  
                  if not boards or #boards == 0 then
                    utils.show_warning('No boards found for project ' .. project_key)
                    return
                  end
                  
                  -- Display boards with IDs for selection
                  local board_list = {'Available boards for project ' .. project_key .. ':', '-----------------------------------------'}
                  for _, board in ipairs(boards) do
                    table.insert(board_list, string.format('%d: %s (%s)', board.id, board.name, board.type or 'scrum'))
                  end
                  
                  vim.api.nvim_echo({{'\n' .. table.concat(board_list, '\n'), 'Normal'}}, false, {})
                  
                  local board_id = vim.fn.input({prompt = "\nEnter board ID to set as default: "})
                  
                  if board_id and board_id ~= '' and tonumber(board_id) then
                    -- Save the board_id to config
                    local current_options = config.options
                    current_options.default_board = board_id
                    
                    -- Save to persistent storage
                    local config_dir = vim.fn.stdpath('config') .. '/jira-nvim'
                    local config_file = config_dir .. '/auth.json'
                    
                    -- Create directory if it doesn't exist
                    if vim.fn.isdirectory(config_dir) == 0 then
                      vim.fn.mkdir(config_dir, 'p')
                    end
                    
                    local creds = {
                      jira_url = current_options.jira_url,
                      jira_email = current_options.jira_email,
                      jira_api_token = current_options.jira_api_token,
                      auth_type = current_options.auth_type,
                      project_key = current_options.project_key,
                      default_board = board_id
                    }
                    
                    local f = io.open(config_file, 'w')
                    if f then
                      f:write(vim.fn.json_encode(creds))
                      f:close()
                      -- Set file permissions to 600 (read/write by owner only)
                      vim.fn.system('chmod 600 ' .. config_file)
                      utils.show_info('Default board set to: ' .. board_id)
                      
                      -- Ask if they want to see the current sprint
                      vim.defer_fn(function()
                        local want_sprint = vim.fn.input({prompt = "\nDo you want to see issues in the current sprint? (y/n): "})
                        if want_sprint:lower() == 'y' then
                          cli.current_sprint()
                        end
                      end, 500)
                    else
                      utils.show_error('Failed to save configuration')
                    end
                  else
                    utils.show_warning('No valid board ID provided')
                  end
                end)
              end, 500)
            end
          end, 1000)
        end
      end
    end)
  end, { desc = 'Setup Jira API connection' })
  
  -- Register API test command
  vim.api.nvim_create_user_command('JiraTestConnection', function()
    utils.show_info('Testing Jira API connection...')
    api.get_current_user(function(err, data)
      if err then
        utils.show_error('Connection failed: ' .. err .. '\n\nTry running :JiraSetup to reconfigure')
      else
        utils.show_info('Connection successful! Connected as: ' .. data.displayName)
      end
    end)
  end, { desc = 'Test Jira API connection' })
  
  -- Register init command for easy setup
  vim.api.nvim_create_user_command('JiraInit', function()
    vim.cmd('JiraSetup')
  end, { desc = 'Initialize Jira plugin' })
  
  -- Show status of Jira configuration
  vim.api.nvim_create_user_command('JiraStatus', function()
    local url = config.get('jira_url') or 'Not set'
    local email = config.get('jira_email') or 'Not set'
    local auth_type = config.get('auth_type') or 'basic'
    local project = config.get('project_key') or 'None'
    local board = config.get('default_board') or 'None'
    local token_status = config.get('jira_api_token') and 'Set' or 'Not set'
    
    local status_text = {
      '🔌 Jira Configuration Status',
      '============================',
      '',
      '🌐 URL: ' .. url,
      '👤 Email: ' .. email,
      '🔐 Auth Type: ' .. auth_type,
      '🔑 API Token: ' .. token_status,
      '📊 Default Project: ' .. project,
      '📋 Default Board ID: ' .. board,
      '',
      'Commands:',
      '  :JiraSetup - Configure connection settings',
      '  :JiraTestConnection - Test API connection',
      '  :JiraInit - Initialize configuration',
    }
    
    ui.show_output('Jira Status', table.concat(status_text, '\n'))
    
    -- Also try to test the connection in background
    api.get_current_user(function(err, data)
      if err then
        utils.show_error('Connection test failed: ' .. err)
      else
        utils.show_info('Connection successful! Connected as: ' .. data.displayName)
      end
    end)
  end, { desc = 'Show Jira connection status' })
  
  vim.api.nvim_create_user_command('JiraIssueList', function(args)
    if args.args and args.args ~= '' then
      cli.issue_list(args.args)
    else
      form.list_issues()
    end
  end, {
    nargs = '*',
    desc = 'List Jira issues'
  })
  
  vim.api.nvim_create_user_command('JiraIssueView', function(args)
    cli.issue_view(args.args)
  end, {
    nargs = 1,
    desc = 'View Jira issue details'
  })
  
  vim.api.nvim_create_user_command('JiraIssueCreate', function(args)
    if args.args and args.args ~= '' then
      cli.issue_create(args.args)
    else
      form.create_issue()
    end
  end, {
    nargs = '*',
    desc = 'Create new Jira issue'
  })
  
  vim.api.nvim_create_user_command('JiraSprintList', function(args)
    local arg_str = args.args or ""
    if arg_str == "--current" then
      cli.current_sprint()
    else
      cli.sprint_list(args.args)
    end
  end, {
    nargs = '*',
    desc = 'List sprints'
  })
  
  vim.api.nvim_create_user_command('JiraEpicList', function(args)
    cli.epic_list(args.args)
  end, {
    nargs = '*',
    desc = 'List epics'
  })
  
  vim.api.nvim_create_user_command('JiraOpen', function(args)
    cli.open(args.args)
  end, {
    nargs = '?',
    desc = 'Open Jira issue or project in browser'
  })
  
  vim.api.nvim_create_user_command('JiraProjectList', function(args)
    local search = require('jira-nvim.search')
    if pcall(require, 'telescope') then
      search.telescope_search_projects()
    else
      cli.project_list()
    end
  end, {
    desc = 'List Jira projects (with fuzzy search if telescope available)'
  })
  
  vim.api.nvim_create_user_command('JiraBoardList', function(args)
    local search = require('jira-nvim.search')
    if pcall(require, 'telescope') then
      search.telescope_search_boards(args.args)
    else
      cli.board_list(args.args)
    end
  end, {
    nargs = '?',
    desc = 'List Jira boards (with fuzzy search if telescope available)'
  })
  
  vim.api.nvim_create_user_command('JiraProjectBoards', function()
    local project_key = config.get('project_key') or config.get('default_project')
    
    if not project_key or project_key == '' then
      utils.show_error('No default project configured. Please set a project in the configuration.')
      return
    end
    
    local search = require('jira-nvim.search')
    if pcall(require, 'telescope') then
      search.telescope_search_boards(project_key)
    else
      cli.board_list(project_key)
    end
  end, {
    desc = 'List boards for the default project'
  })
  
  vim.api.nvim_create_user_command('JiraIssueTransition', function(args)
    local input = args.args
    local issue_key, rest = input:match("^(%S+)%s+(.*)$")
    
    if not issue_key or not rest then
      vim.notify('Usage: JiraIssueTransition ISSUE-KEY "STATE" ["COMMENT"] ["ASSIGNEE"] ["RESOLUTION"]', vim.log.levels.WARN)
      return
    end
    
    -- Parse quoted arguments
    local parts = {}
    local current = ""
    local in_quotes = false
    local i = 1
    
    while i <= #rest do
      local char = rest:sub(i, i)
      if char == '"' then
        if in_quotes then
          table.insert(parts, current)
          current = ""
          in_quotes = false
        else
          in_quotes = true
        end
      elseif char == ' ' and not in_quotes then
        if current ~= "" then
          table.insert(parts, current)
          current = ""
        end
      else
        current = current .. char
      end
      i = i + 1
    end
    
    if current ~= "" then
      table.insert(parts, current)
    end
    
    local state = parts[1]
    local comment = parts[2]
    local assignee = parts[3]
    local resolution = parts[4]
    
    if not state then
      vim.notify('State is required for issue transition', vim.log.levels.WARN)
      return
    end
    
    cli.issue_transition(issue_key, state, comment, assignee, resolution)
  end, {
    nargs = '+',
    desc = 'Transition Jira issue to new state'
  })
  
  vim.api.nvim_create_user_command('JiraIssueComment', function(args)
    local input = args.args
    local issue_key, comment = input:match('^(%S+)%s+(.+)$')
    
    if not issue_key then
      vim.notify('Usage: JiraIssueComment ISSUE-KEY [comment text]', vim.log.levels.WARN)
      return
    end
    
    if comment and comment ~= '' then
      cli.issue_comment_add(issue_key, comment)
    else
      ui.show_comment_buffer(issue_key)
    end
  end, {
    nargs = '+',
    desc = 'Add comment to Jira issue'
  })
  
  vim.api.nvim_create_user_command('JiraIssueComments', function(args)
    local parts = vim.split(args.args, ' ', { plain = true })
    local issue_key = parts[1]
    local count = tonumber(parts[2]) or 5
    
    if not issue_key then
      vim.notify('Usage: JiraIssueComments ISSUE-KEY [count]', vim.log.levels.WARN)
      return
    end
    
    cli.issue_view(issue_key, count)
  end, {
    nargs = '+',
    desc = 'View comments for Jira issue'
  })
  
  vim.api.nvim_create_user_command('JiraIssueAssign', function(args)
    local parts = vim.split(args.args, ' ', { plain = true })
    local issue_key = parts[1]
    local assignee = parts[2]
    
    if not issue_key then
      vim.notify('Usage: JiraIssueAssign ISSUE-KEY ASSIGNEE', vim.log.levels.WARN)
      return
    end
    
    if not assignee then
      vim.notify('Usage: JiraIssueAssign ISSUE-KEY ASSIGNEE (use "me", username, email, or "unassign")', vim.log.levels.WARN)
      return
    end
    
    cli.issue_assign(issue_key, assignee)
  end, {
    nargs = '+',
    desc = 'Assign Jira issue to user'
  })
  
  vim.api.nvim_create_user_command('JiraIssueWatch', function(args)
    local parts = vim.split(args.args, ' ', { plain = true })
    local issue_key = parts[1]
    local watcher = parts[2] or 'me'
    
    if not issue_key then
      vim.notify('Usage: JiraIssueWatch ISSUE-KEY [WATCHER]', vim.log.levels.WARN)
      return
    end
    
    cli.issue_watch(issue_key, watcher)
  end, {
    nargs = '+',
    desc = 'Add watcher to Jira issue'
  })
  
  -- Search and navigation commands
  vim.api.nvim_create_user_command('JiraSearch', function()
    search.telescope_search_issues()
  end, {
    desc = 'Fuzzy search Jira issues'
  })
  
  vim.api.nvim_create_user_command('JiraHistory', function()
    search.show_history()
  end, {
    desc = 'Show issue history'
  })
  
  vim.api.nvim_create_user_command('JiraBookmarks', function()
    search.show_bookmarks()
  end, {
    desc = 'Show bookmarked issues'
  })
  
  vim.api.nvim_create_user_command('JiraBookmark', function(args)
    local parts = vim.split(args.args, ' ', { plain = true })
    local issue_key = parts[1]
    local description = table.concat(vim.list_slice(parts, 2), ' ')
    
    if not issue_key then
      vim.notify('Usage: JiraBookmark ISSUE-KEY [description]', vim.log.levels.WARN)
      return
    end
    
    search.toggle_bookmark(issue_key, description)
  end, {
    nargs = '+',
    desc = 'Toggle bookmark for issue'
  })
  
  vim.api.nvim_create_user_command('JiraJQL', function()
    search.jql_search()
  end, {
    desc = 'Search issues with JQL'
  })
  
  vim.api.nvim_create_user_command('JiraMyIssues', function()
    search.show_my_issues()
  end, {
    desc = 'Show my assigned issues'
  })
  
  vim.api.nvim_create_user_command('JiraRecentIssues', function()
    search.show_recent_issues()
  end, {
    desc = 'Show recently created issues'
  })
  
  vim.api.nvim_create_user_command('JiraHighPriorityIssues', function()
    search.show_high_priority_issues()
  end, {
    desc = 'Show high priority issues'
  })
  
  vim.api.nvim_create_user_command('JiraUnassignedIssues', function()
    search.show_unassigned_issues()
  end, {
    desc = 'Show unassigned issues'
  })
  
  vim.api.nvim_create_user_command('JiraCurrentSprint', function()
    cli.current_sprint()
  end, {
    desc = 'Show issues from the current active sprint'
  })
  
  vim.api.nvim_create_user_command('JiraSetDefaultBoard', function(args)
    if args.args and args.args ~= '' then
      local board_id = args.args
      
      -- Save the board_id to config
      local current_options = config.options
      current_options.default_board = board_id
      
      -- Save to persistent storage
      local config_dir = vim.fn.stdpath('config') .. '/jira-nvim'
      local config_file = config_dir .. '/auth.json'
      
      -- Create directory if it doesn't exist
      if vim.fn.isdirectory(config_dir) == 0 then
        vim.fn.mkdir(config_dir, 'p')
      end
      
      local creds = {
        jira_url = current_options.jira_url,
        jira_email = current_options.jira_email,
        jira_api_token = current_options.jira_api_token,
        auth_type = current_options.auth_type,
        project_key = current_options.project_key,
        default_board = board_id
      }
      
      local f = io.open(config_file, 'w')
      if f then
        f:write(vim.fn.json_encode(creds))
        f:close()
        -- Set file permissions to 600 (read/write by owner only)
        vim.fn.system('chmod 600 ' .. config_file)
        utils.show_info('Default board set to: ' .. board_id .. '\n\nTo find your board ID, use :JiraProjectBoards to list boards for your default project\nor :JiraBoardList to see all available boards.')
      else
        utils.show_error('Failed to save configuration')
      end
    else
      utils.show_warning('Usage: JiraSetDefaultBoard <board_id>\n\nTo find your board ID, use :JiraProjectBoards or :JiraBoardList to see available boards.')
    end
  end, {
    nargs = 1,
    desc = 'Set default board ID for sprints'
  })
  
  vim.api.nvim_create_user_command('JiraShowBoards', function()
    local project_key = config.get('project_key') or config.get('default_project')
    
    if not project_key or project_key == '' then
      utils.show_error('No default project configured. Please set a project in the configuration.')
      return
    end
    
    utils.show_info('Loading boards for project ' .. project_key)
    
    api.get_project_boards(project_key, function(err, boards)
      if err then
        utils.show_error('Error loading project boards: ' .. err)
        return
      end
      
      if not boards or #boards == 0 then
        utils.show_warning('No boards found for project ' .. project_key)
        return
      end
      
      -- Display boards with IDs for selection
      local board_list = {'Available boards for project ' .. project_key .. ':', '-----------------------------------------'}
      
      for _, board in ipairs(boards) do
        table.insert(board_list, string.format('%d: %s (%s)', board.id, board.name, board.type or 'scrum'))
      end
      
      local output = table.concat(board_list, '\n')
      ui.show_output('Project Boards with IDs', output)
    end)
  end, {
    desc = 'Show available board IDs for the default project'
  })
  
  vim.api.nvim_create_user_command('JiraHelp', function()
    ui.show_help()
  end, {
    desc = 'Show Jira plugin help'
  })
  
  -- Convenience commands for quick access
  vim.api.nvim_create_user_command('JiraRecentIssues', function()
    form.recent_issues()
  end, {
    desc = 'Show issues created in the last 7 days'
  })
  
  vim.api.nvim_create_user_command('JiraHighPriorityIssues', function()
    form.high_priority_issues()
  end, {
    desc = 'Show high priority issues'
  })
  
  vim.api.nvim_create_user_command('JiraUnassignedIssues', function()
    form.unassigned_issues()
  end, {
    desc = 'Show unassigned issues'
  })
end

return M