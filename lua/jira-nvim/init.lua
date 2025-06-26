local M = {}

local config = require('jira-nvim.config')
local cli = require('jira-nvim.cli')
local ui = require('jira-nvim.ui')
local form = require('jira-nvim.form')
local user = require('jira-nvim.user')

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
    cli.project_list()
  end, {
    desc = 'List Jira projects'
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
      vim.notify('Usage: JiraIssueTransition ISSUE-KEY STATE [COMMENT] [ASSIGNEE] [RESOLUTION]', vim.log.levels.WARN)
      return
    end
    
    cli.issue_transition(issue_key, state, comment, assignee, resolution)
  end, {
    nargs = '+',
    desc = 'Transition Jira issue to new state'
  })
  
  vim.api.nvim_create_user_command('JiraHelp', function()
    ui.show_help()
  end, {
    desc = 'Show Jira plugin help'
  })
end

return M