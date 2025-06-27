local M = {}

local config = require('jira-nvim.config')
local cli = require('jira-nvim.cli')
local ui = require('jira-nvim.ui')
local utils = require('jira-nvim.utils')

-- Issue history storage
local issue_history = {}
local max_history = 50

-- Bookmarks storage
local bookmarks = {}

-- Check for telescope integration
local has_telescope = pcall(require, 'telescope')
local telescope = has_telescope and require('telescope') or nil

-- Add issue to history
function M.add_to_history(issue_key)
  -- Remove if already exists
  for i, item in ipairs(issue_history) do
    if item.key == issue_key then
      table.remove(issue_history, i)
      break
    end
  end
  
  -- Add to beginning
  table.insert(issue_history, 1, {
    key = issue_key,
    timestamp = os.time()
  })
  
  -- Limit history size
  if #issue_history > max_history then
    table.remove(issue_history, max_history + 1)
  end
end

-- Get issue history
function M.get_history()
  return issue_history
end

-- Clear history
function M.clear_history()
  issue_history = {}
end

-- Add bookmark
function M.add_bookmark(issue_key, description)
  bookmarks[issue_key] = {
    key = issue_key,
    description = description or '',
    timestamp = os.time()
  }
end

-- Remove bookmark
function M.remove_bookmark(issue_key)
  bookmarks[issue_key] = nil
end

-- Get bookmarks
function M.get_bookmarks()
  local bookmark_list = {}
  for _, bookmark in pairs(bookmarks) do
    table.insert(bookmark_list, bookmark)
  end
  
  -- Sort by timestamp (newest first)
  table.sort(bookmark_list, function(a, b)
    return a.timestamp > b.timestamp
  end)
  
  return bookmark_list
end

-- Toggle bookmark
function M.toggle_bookmark(issue_key, description)
  if bookmarks[issue_key] then
    M.remove_bookmark(issue_key)
    utils.show_info('Removed bookmark for ' .. issue_key)
  else
    M.add_bookmark(issue_key, description)
    utils.show_info('Added bookmark for ' .. issue_key)
  end
end

-- Fuzzy search issues using telescope (if available)
function M.telescope_search_issues()
  if not has_telescope then
    utils.show_error('Telescope not available. Install telescope.nvim for fuzzy search.')
    return
  end
  
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  
  -- Get recent issues first
  local issues = {}
  for _, item in ipairs(issue_history) do
    table.insert(issues, item.key)
  end
  
  pickers.new({}, {
    prompt_title = 'Search Jira Issues',
    finder = finders.new_table({
      results = issues,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry,
          ordinal = entry,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          cli.issue_view(selection.value)
        end
      end)
      return true
    end,
  }):find()
end

-- Show issue history
function M.show_history()
  if #issue_history == 0 then
    utils.show_info('No issue history available')
    return
  end
  
  local history_lines = {'Recent Issues:', '=============', ''}
  
  for _, item in ipairs(issue_history) do
    local date = os.date('%Y-%m-%d %H:%M', item.timestamp)
    table.insert(history_lines, string.format('🕒 %s - %s', item.key, date))
  end
  
  table.insert(history_lines, '')
  table.insert(history_lines, 'Press <CR> to view issue, q to close')
  
  ui.show_output('Issue History', table.concat(history_lines, '\n'))
end

-- Show bookmarks
function M.show_bookmarks()
  local bookmark_list = M.get_bookmarks()
  
  if #bookmark_list == 0 then
    utils.show_info('No bookmarks available')
    return
  end
  
  local bookmark_lines = {'Bookmarked Issues:', '=================', ''}
  
  for _, bookmark in ipairs(bookmark_list) do
    local date = os.date('%Y-%m-%d %H:%M', bookmark.timestamp)
    local desc = bookmark.description ~= '' and ' - ' .. bookmark.description or ''
    table.insert(bookmark_lines, string.format('🔖 %s%s (%s)', bookmark.key, desc, date))
  end
  
  table.insert(bookmark_lines, '')
  table.insert(bookmark_lines, 'Press <CR> to view issue, b to toggle bookmark, q to close')
  
  ui.show_output('Bookmarked Issues', table.concat(bookmark_lines, '\n'))
end

-- Quick navigation to linked issues
function M.find_linked_issues(content)
  local linked_issues = {}
  
  -- Extract issue keys from content
  for issue_key in content:gmatch('([A-Z]+-[0-9]+)') do
    if not vim.tbl_contains(linked_issues, issue_key) then
      table.insert(linked_issues, issue_key)
    end
  end
  
  return linked_issues
end

-- Enhanced search with JQL support
function M.jql_search()
  vim.ui.input({
    prompt = 'Enter JQL query: ',
    default = 'project IS NOT EMPTY ORDER BY updated DESC'
  }, function(jql)
    if jql and jql ~= '' then
      cli.issue_list('-q"' .. jql .. '"')
    end
  end)
end

-- Quick filters
function M.show_my_issues()
  cli.issue_list('-a$(jira me)')
end

function M.show_issues_by_status(status)
  status = status or 'To Do'
  cli.issue_list('-s"' .. status .. '"')
end

function M.show_issues_by_priority(priority)
  priority = priority or 'High'
  cli.issue_list('-y"' .. priority .. '"')
end

return M