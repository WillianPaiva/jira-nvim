local M = {}

local config = require('jira-nvim.config')

-- Check for optional dependencies
local has_devicons = pcall(require, 'nvim-web-devicons')
local devicons = has_devicons and require('nvim-web-devicons') or nil

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

-- Get icon for issue type or status
local function get_jira_icon(text)
  if not devicons then
    return ''
  end
  
  local icon_map = {
    ['Bug'] = '🐛',
    ['Task'] = '📋',
    ['Story'] = '📖',
    ['Epic'] = '🎯',
    ['Sub-task'] = '📝',
    ['Improvement'] = '⚡',
    ['New Feature'] = '✨',
    ['To Do'] = '⏳',
    ['In Progress'] = '🔄',
    ['Done'] = '✅',
    ['Closed'] = '🔒',
    ['Resolved'] = '✔️',
    ['Open'] = '🔓',
    ['Highest'] = '🔴',
    ['High'] = '🟠',
    ['Medium'] = '🟡',
    ['Low'] = '🟢',
    ['Lowest'] = '🔵'
  }
  
  for key, icon in pairs(icon_map) do
    if text:find(key) then
      return icon .. ' '
    end
  end
  
  return ''
end

-- Format Jira output with better visual indicators
local function format_jira_content(content)
  if not config.get('enhanced_formatting') then
    return vim.split(content, '\n', { plain = true })
  end
  
  local lines = vim.split(content, '\n', { plain = true })
  local formatted_lines = {}
  
  for _, line in ipairs(lines) do
    -- Add icons to issue types and statuses if enabled
    if config.get('show_icons') then
      local icon = get_jira_icon(line)
      if icon ~= '' then
        line = icon .. line
      end
      
      -- Enhance issue key highlighting
      line = line:gsub('([A-Z]+-[0-9]+)', '🎫 %1')
      
      -- Add visual separators
      if line:match('^%s*[─┌┐└┘│├┤┬┴┼]') then
        line = '📊 ' .. line
      end
    end
    
    table.insert(formatted_lines, line)
  end
  
  return formatted_lines
end

function M.show_output(title, content)
  local lines = format_jira_content(content)
  
  local buf, win
  if config.get('use_floating_window') then
    buf, win = M.create_floating_window(title, content)
  else
    buf, win = M.create_split_window(title, content)
  end
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Add a small delay before making the buffer non-modifiable
  -- This allows plugins like img-clip.nvim to complete paste operations
  vim.defer_fn(function()
    -- Check if the buffer still exists before setting options
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    end
  end, 100)
  
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
      -- Extract action info from buffer title
      local action_type = title:match('^([^:]+):')
      
      if action_type == 'Issue' then
        -- Extract issue key
        local issue_key = title:match('Issue:%s*([A-Z]+-[0-9]+)')
        if issue_key then
          require('jira-nvim.cli').issue_view(issue_key)
        end
      elseif action_type == 'Jira Issues' then
        require('jira-nvim.cli').issue_list()
      elseif action_type == 'Jira Projects' then
        require('jira-nvim.cli').project_list()
      elseif action_type == 'Jira Boards' then
        require('jira-nvim.cli').board_list()
      elseif action_type == 'Jira Sprints' then
        require('jira-nvim.cli').sprint_list()
      elseif action_type == 'Jira Epics' then
        require('jira-nvim.cli').epic_list()
      else
        utils.show_info('Refreshing not available for this view')
      end
    end,
    desc = 'Refresh content'
  })
  
  local function get_issue_key_under_cursor()
    local line = vim.api.nvim_get_current_line()
    local issue_key = line:match('([A-Z]+-[0-9]+)')
    return issue_key
  end
  
  local function get_issue_key_from_buffer(title)
    -- First try to extract from buffer title (e.g., "Issue: PROJ-123")
    local issue_key = title:match('Issue:%s*([A-Z]+-[0-9]+)')
    if issue_key then
      return issue_key
    end
    
    -- Fallback to cursor detection
    return get_issue_key_under_cursor()
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
  
  -- Only set the transition keymap if it exists in config
  if keymaps.transition_issue then
    vim.api.nvim_buf_set_keymap(buf, 'n', keymaps.transition_issue, '', {
      noremap = true,
      silent = true,
      callback = function()
        local issue_key = get_issue_key_from_buffer(title)
        if issue_key then
          -- First get available transitions
          require('jira-nvim.cli').get_available_transitions(issue_key, function(err, states)
            if err then
              -- Fallback to manual input if we can't get transitions
              vim.ui.input({
                prompt = 'New state for ' .. issue_key .. ': ',
              }, function(state)
                if state and state ~= '' then
                  require('jira-nvim.cli').issue_transition(issue_key, state)
                end
              end)
            else
              -- Show available states as options
              vim.ui.select(states, {
                prompt = 'Select new state for ' .. issue_key .. ':',
                format_item = function(item)
                  return item
                end,
              }, function(choice)
                if choice then
                  require('jira-nvim.cli').issue_transition(issue_key, choice)
                end
              end)
            end
          end)
        else
          vim.notify('No issue key found in buffer', vim.log.levels.WARN)
        end
      end,
      desc = 'Transition issue state'
    })
  end
  
  -- Add comment keymap if configured
  if keymaps.comment_issue then
    vim.api.nvim_buf_set_keymap(buf, 'n', keymaps.comment_issue, '', {
      noremap = true,
      silent = true,
      callback = function()
        local issue_key = get_issue_key_from_buffer(title)
        if issue_key then
          M.show_comment_buffer(issue_key)
        else
          vim.notify('No issue key found in buffer', vim.log.levels.WARN)
        end
      end,
      desc = 'Add comment to issue'
    })
  end
  
  -- Add view comments keymap if configured  
  if keymaps.view_comments then
    vim.api.nvim_buf_set_keymap(buf, 'n', keymaps.view_comments, '', {
      noremap = true,
      silent = true,
      callback = function()
        local issue_key = get_issue_key_from_buffer(title)
        if issue_key then
          require('jira-nvim.cli').issue_view(issue_key, 10) -- Show 10 recent comments
        else
          vim.notify('No issue key found in buffer', vim.log.levels.WARN)
        end
      end,
      desc = 'View issue comments'
    })
  end
  
  -- Add assign keymap if configured
  if keymaps.assign_issue then
    vim.api.nvim_buf_set_keymap(buf, 'n', keymaps.assign_issue, '', {
      noremap = true,
      silent = true,
      callback = function()
        local issue_key = get_issue_key_from_buffer(title)
        if issue_key then
          vim.ui.input({
            prompt = 'Assign ' .. issue_key .. ' to (me/username/email/unassign): ',
            default = 'me'
          }, function(assignee)
            if assignee and assignee ~= '' then
              require('jira-nvim.cli').issue_assign(issue_key, assignee)
            end
          end)
        else
          vim.notify('No issue key found in buffer', vim.log.levels.WARN)
        end
      end,
      desc = 'Assign issue'
    })
  end
  
  -- Add watch keymap if configured
  if keymaps.watch_issue then
    vim.api.nvim_buf_set_keymap(buf, 'n', keymaps.watch_issue, '', {
      noremap = true,
      silent = true,
      callback = function()
        local issue_key = get_issue_key_from_buffer(title)
        if issue_key then
          vim.ui.input({
            prompt = 'Add watcher to ' .. issue_key .. ' (me/username/email): ',
            default = 'me'
          }, function(watcher)
            if watcher and watcher ~= '' then
              require('jira-nvim.cli').issue_watch(issue_key, watcher)
            end
          end)
        else
          vim.notify('No issue key found in buffer', vim.log.levels.WARN)
        end
      end,
      desc = 'Add watcher to issue'
    })
  end
  
  -- Add bookmark toggle keymap
  if keymaps.toggle_bookmark then
    vim.api.nvim_buf_set_keymap(buf, 'n', keymaps.toggle_bookmark, '', {
      noremap = true,
      silent = true,
      callback = function()
        local issue_key = get_issue_key_from_buffer(title)
        if issue_key then
          require('jira-nvim.search').toggle_bookmark(issue_key)
        else
          vim.notify('No issue key found in buffer', vim.log.levels.WARN)
        end
      end,
      desc = 'Toggle bookmark'
    })
  end
  
  -- Add history keymap
  if keymaps.show_history then
    vim.api.nvim_buf_set_keymap(buf, 'n', keymaps.show_history, '', {
      noremap = true,
      silent = true,
      callback = function()
        require('jira-nvim.search').show_history()
      end,
      desc = 'Show issue history'
    })
  end
  
  -- Add bookmarks keymap
  if keymaps.show_bookmarks then
    vim.api.nvim_buf_set_keymap(buf, 'n', keymaps.show_bookmarks, '', {
      noremap = true,
      silent = true,
      callback = function()
        require('jira-nvim.search').show_bookmarks()
      end,
      desc = 'Show bookmarks'
    })
  end
  
  -- Add fuzzy search keymap
  if keymaps.fuzzy_search then
    vim.api.nvim_buf_set_keymap(buf, 'n', keymaps.fuzzy_search, '', {
      noremap = true,
      silent = true,
      callback = function()
        require('jira-nvim.search').telescope_search_issues()
      end,
      desc = 'Fuzzy search issues'
    })
  end
  
  vim.api.nvim_win_set_option(win, 'wrap', false)
  vim.api.nvim_win_set_option(win, 'cursorline', true)
end

function M.show_help()
  local help_text = {
    'Jira Neovim Plugin Help',
    '========================',
    '',
    'Commands:',
    '  :JiraIssueList [jql]         - List issues matching JQL query',
    '  :JiraIssueView <key>          - View issue details',
    '  :JiraIssueCreate [args]       - Create new issue',
    '  :JiraIssueComment <key> [msg] - Add comment to issue',
    '  :JiraIssueComments <key> [n]  - View n recent comments (default: 5)',
    '  :JiraIssueAssign <key> <user> - Assign issue to user',
    '  :JiraIssueWatch <key> [user]  - Add watcher to issue (default: me)',
    '  :JiraSprintList [board_id]    - List sprints',
    '  :JiraEpicList [board_id]      - List epics',
    '  :JiraProjectList              - Browse projects (with fuzzy search)',
    '  :JiraBoardList [project_key]   - Browse boards (with fuzzy search)',
    '  :JiraProjectBoards             - List boards for default project',
    '  :JiraOpen [key]               - Open in browser',
    '  :JiraSearch                   - Fuzzy search issues (requires telescope)',
    '  :JiraHistory                  - Show recently viewed issues',
    '  :JiraBookmarks                - Show bookmarked issues',
    '  :JiraBookmark <key> [desc]    - Toggle bookmark for issue',
    '  :JiraJQL                      - Search with JQL query',
    '  :JiraMyIssues                 - Show my assigned issues',
    '  :JiraRecentIssues             - Show recently created issues',
    '  :JiraHighPriorityIssues       - Show high priority issues',
    '  :JiraUnassignedIssues         - Show unassigned issues',
    '  :JiraCurrentSprint            - Show issues from current active sprint',
    '  :JiraShowBoards                - Show board IDs for default project',
    '  :JiraSetDefaultBoard <id>       - Set default board ID for sprints',
    '',
    'Keymaps (in Jira windows):',
    '  q         - Close window',
    '  <C-r>     - Refresh current view',
    '  <CR>      - Open issue in browser',
    '  v         - View issue details',
    '  t         - Transition issue state (shows available options)',
    '  c         - Add comment to issue',
    '  C         - View recent comments',
    '  a         - Assign issue to user',
    '  w         - Add watcher to issue',
    '  b         - Toggle bookmark for issue',
    '  h         - Show issue history',
    '  B         - Show bookmarks',
    '  /         - Fuzzy search issues (requires telescope)',
    '',
    'Examples:',
    '  :JiraIssueList "assignee = currentUser() AND status = \"To Do\""',
    '  :JiraIssueList "project = PROJ AND sprint in openSprints()"',
    '  :JiraIssueView PROJ-123',
    '  :JiraIssueCreate',
    '  :JiraIssueComment PROJ-123 "This is a comment"',
    '  :JiraIssueComments PROJ-123 10',
    '  :JiraIssueAssign PROJ-123 me',
    '  :JiraIssueAssign PROJ-123 john@example.com',
    '  :JiraIssueWatch PROJ-123',
    '  :JiraBookmark PROJ-123 "Important bug to track"',
    '  :JiraSearch  # Opens telescope fuzzy search',
    '  :JiraMyIssues  # Shows issues assigned to me',
    '  :JiraRecentIssues  # Shows issues created in the last 7 days',
    '  :JiraHighPriorityIssues  # Shows high priority issues',
    '  :JiraUnassignedIssues  # Shows issues with no assignee',
    '  :JiraCurrentSprint  # Shows issues in the current sprint',
    '  :JiraSetDefaultBoard 123  # Sets board ID 123 as the default board',
    '  :JiraBoardList PROJ  # Lists all boards for project PROJ',
    '  :JiraProjectBoards  # Lists boards for the default project',
    '  :JiraShowBoards  # Shows board IDs for the default project',
    '',
    'Configuration:',
    '  Create credentials in ' .. vim.fn.stdpath('config') .. '/jira-nvim/auth.json',
    '  or run :JiraSetup to configure interactively',
    '',
    'For more information and documentation, see:',
    '  https://github.com/WillianPaiva/jira-nvim-plugin'
  }
  
  M.show_output('Jira Help', table.concat(help_text, '\n'))
end

function M.show_comment_buffer(issue_key)
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.6)
  local height = math.floor(vim.o.lines * 0.4)
  
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    border = 'rounded',
    title = 'Add Comment to ' .. issue_key,
    title_pos = 'center'
  })
  
  vim.api.nvim_buf_set_option(buf, 'buftype', 'acwrite')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  
  -- Add placeholder text
  local placeholder = {
    '# Add your comment below',
    '',
    '<!-- Write your comment here -->',
    '<!-- You can use markdown formatting -->',
    '<!-- Press <C-s> to submit, <C-c> to cancel -->'
  }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, placeholder)
  
  -- Position cursor after placeholder
  vim.api.nvim_win_set_cursor(win, {6, 0})
  
  -- Set up keymaps for the comment buffer
  local opts = { noremap = true, silent = true, buffer = buf }
  
  -- Submit comment
  vim.keymap.set({'n', 'i'}, '<C-s>', function()
    require('jira-nvim.cli').issue_comment_add_from_buffer(issue_key, buf)
    vim.api.nvim_win_close(win, true)
  end, vim.tbl_extend('force', opts, { desc = 'Submit comment' }))
  
  -- Cancel comment
  vim.keymap.set({'n', 'i'}, '<C-c>', function()
    vim.api.nvim_win_close(win, true)
  end, vim.tbl_extend('force', opts, { desc = 'Cancel comment' }))
  
  -- Alternative close with q in normal mode
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, vim.tbl_extend('force', opts, { desc = 'Close comment buffer' }))
  
  -- Start in insert mode for better UX
  vim.cmd('startinsert')
end

return M