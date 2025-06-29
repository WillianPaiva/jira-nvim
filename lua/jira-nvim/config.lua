local M = {}

local defaults = {
  jira_cmd = 'jira',
  use_floating_window = true,
  window_width = 0.8,
  window_height = 0.8,
  default_project = nil,
  -- Visual enhancements
  show_icons = true,
  show_progress = true,
  enhanced_formatting = true,
  -- Custom colors for different issue types/statuses
  colors = {
    issue_key = 'Identifier',
    status = 'Statement',
    priority = 'Special',
    issue_type = 'Type',
    user = 'PreProc'
  },
  keymaps = {
    close = 'q',
    refresh = '<C-r>',
    open_browser = '<CR>',
    view_issue = 'v',
    transition_issue = 't',
    comment_issue = 'c',
    view_comments = 'C',
    assign_issue = 'a',
    watch_issue = 'w',
    toggle_bookmark = 'b',
    show_history = 'h',
    show_bookmarks = 'B',
    fuzzy_search = '/'
  }
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend('force', defaults, opts or {})
end

function M.get(key)
  return M.options[key]
end

return M