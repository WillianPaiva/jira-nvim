local M = {}

local config = require('jira-nvim.config')
local cli = require('jira-nvim.cli')
local ui = require('jira-nvim.ui')
local form = require('jira-nvim.form')
local user = require('jira-nvim.user')
local search = require('jira-nvim.search')

-- Check if LazyVim is available for better integration
local has_lazyvim = pcall(require, "lazyvim.util")

function M.setup(opts)
  config.setup(opts or {})
  
  -- Initialize user cache
  user.init()
  
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
    cli.sprint_list(args.args)
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
    cli.project_list(args.args)
  end, {
    nargs = '*',
    desc = 'List Jira projects'
  })
  
  vim.api.nvim_create_user_command('JiraProjectCreate', function(args)
    if args.args and args.args ~= '' then
      cli.project_create(args.args)
    else
      form.create_project()
    end
  end, {
    nargs = '*',
    desc = 'Create new Jira project'
  })

  vim.api.nvim_create_user_command('JiraBoardList', function(args)
    cli.board_list()
  end, {
    desc = 'List Jira boards'
  })
  
  vim.api.nvim_create_user_command('JiraIssueTransition', function(args)
    local parts = vim.split(args.args, ' ', { plain = true })
    local issue_key = parts[1]
    local state = parts[2]
    local comment = parts[3]
    local assignee = parts[4]
    local resolution = parts[5]

    if not issue_key or not state then
      utils.show_warning('Usage: JiraIssueTransition <issue_key> <state> [comment] [assignee] [resolution]')
      return
    end

    cli.issue_transition(issue_key, state, comment, assignee, resolution)
  end, {
    nargs = '+',
    desc = 'Transition Jira issue to new state',
    complete = function(arglead, cmdline, cursorpos)
      local parts = vim.split(cmdline, ' ', { plain = true })
      if #parts == 2 then
        -- No completion for issue key
        return {}
      end
      if #parts == 3 then
        -- Completion for state
        local issue_key = parts[2]
        local transitions = {}
        cli.get_available_transitions(issue_key, function(err, states)
          if not err then
            transitions = states
          end
        end)
        return transitions
      end
      return {}
    end
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
  
  vim.api.nvim_create_user_command('JiraHelp', function()
    ui.show_help()
  end, {
    desc = 'Show Jira plugin help'
  })
end

return M