local M = {}

local defaults = {
  jira_cmd = 'jira',
  use_floating_window = true,
  window_width = 0.8,
  window_height = 0.8,
  default_project = nil,
  keymaps = {
    close = 'q',
    refresh = '<C-r>',
    open_browser = '<CR>',
    view_issue = 'v',
    transition_issue = 't'
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