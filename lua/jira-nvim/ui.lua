local M = {}

local config = require('jira-nvim.config')

function M.create_floating_window(title, content)
  local width = math.floor(vim.o.columns * config.get('window_width'))
  local height = math.floor(vim.o.lines * config.get('window_height'))
  
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)
  
  local buf = vim.api.nvim_create_buf(false, true)
  
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'jira')
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    border = 'rounded',
    title = title,
    title_pos = 'center'
  })
  
  return buf, win
end

function M.create_split_window(title, content)
  vim.cmd('split')
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'jira')
  
  return buf, vim.api.nvim_get_current_win()
end

function M.show_output(title, content)
  local lines = vim.split(content, '\n', { plain = true })
  
  local buf, win
  if config.get('use_floating_window') then
    buf, win = M.create_floating_window(title, content)
  else
    buf, win = M.create_split_window(title, content)
  end
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  
  local keymaps = config.get('keymaps')
  
  vim.api.nvim_buf_set_keymap(buf, 'n', keymaps.close, ':q<CR>', {
    noremap = true,
    silent = true,
    desc = 'Close window'
  })
  
  vim.api.nvim_buf_set_keymap(buf, 'n', keymaps.refresh, '', {
    noremap = true,
    silent = true,
    callback = function()
      vim.notify('Refresh functionality not implemented yet', vim.log.levels.INFO)
    end,
    desc = 'Refresh content'
  })
  
  local function get_issue_key_under_cursor()
    local line = vim.api.nvim_get_current_line()
    local issue_key = line:match('([A-Z]+-[0-9]+)')
    return issue_key
  end
  
  vim.api.nvim_buf_set_keymap(buf, 'n', keymaps.open_browser, '', {
    noremap = true,
    silent = true,
    callback = function()
      local issue_key = get_issue_key_under_cursor()
      if issue_key then
        require('jira-nvim.cli').open(issue_key)
      else
        vim.notify('No issue key found under cursor', vim.log.levels.WARN)
      end
    end,
    desc = 'Open issue in browser'
  })
  
  vim.api.nvim_buf_set_keymap(buf, 'n', keymaps.view_issue, '', {
    noremap = true,
    silent = true,
    callback = function()
      local issue_key = get_issue_key_under_cursor()
      if issue_key then
        require('jira-nvim.cli').issue_view(issue_key)
      else
        vim.notify('No issue key found under cursor', vim.log.levels.WARN)
      end
    end,
    desc = 'View issue details'
  })
  
  vim.api.nvim_win_set_option(win, 'wrap', false)
  vim.api.nvim_win_set_option(win, 'cursorline', true)
end

function M.show_help()
  local help_text = {
    'Jira Neovim Plugin Help',
    '========================',
    '',
    'Commands:',
    '  :JiraIssueList [args]     - List issues',
    '  :JiraIssueView <key>      - View issue details',
    '  :JiraIssueCreate [args]   - Create new issue',
    '  :JiraSprintList [args]    - List sprints',
    '  :JiraEpicList [args]      - List epics',
    '  :JiraOpen [key]           - Open in browser',
    '',
    'Keymaps (in Jira windows):',
    '  q         - Close window',
    '  <C-r>     - Refresh (not implemented)',
    '  <CR>      - Open issue in browser',
    '  v         - View issue details',
    '',
    'Examples:',
    '  :JiraIssueList -a$(jira me) -s"To Do"',
    '  :JiraIssueView PROJ-123',
    '  :JiraIssueCreate -tBug -s"Bug title"'
  }
  
  M.show_output('Jira Help', table.concat(help_text, '\n'))
end

return M