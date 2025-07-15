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
    timestamp = os.time(),
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
    timestamp = os.time(),
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
    utils.show_info('Removed bookmark for ' .. issue_key, { searching = true })
  else
    M.add_bookmark(issue_key, description)
    utils.show_info('Added bookmark for ' .. issue_key, { searching = true })
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

  -- Show loading indicator
  utils.show_info('Searching for issues...', { searching = true })

  -- Get recent issues first
  local issues = {}
  for _, item in ipairs(issue_history) do
    table.insert(issues, item.key)
  end

  pickers
    .new({}, {
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
    })
    :find()
end

-- Show issue history
function M.show_history()
  if #issue_history == 0 then
    utils.show_info('No issue history available')
    return
  end

  local history_lines = { 'Recent Issues:', '=============', '' }

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

  local bookmark_lines = { 'Bookmarked Issues:', '=================', '' }

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
    default = 'project IS NOT EMPTY ORDER BY updated DESC',
  }, function(jql)
    if jql and jql ~= '' then
      cli.issue_list('-q"' .. jql .. '"')
    end
  end)
end

-- Fuzzy search projects using telescope
function M.telescope_search_projects()
  if not has_telescope then
    utils.show_error('Telescope not available. Install telescope.nvim for fuzzy search.')
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  -- Show loading indicator
  local spinner = utils.create_spinner('Loading projects')

  -- Get projects
  local api = require('jira-nvim.api')
  api.get_projects(function(err, projects)
    spinner.stop()

    if err then
      utils.show_error('Error loading projects: ' .. err)
      return
    end

    if not projects or #projects == 0 then
      utils.show_info('No projects found')
      return
    end

    local project_entries = {}
    for _, project in ipairs(projects) do
      table.insert(project_entries, {
        key = project.key,
        name = project.name,
        display = project.key .. ' - ' .. project.name,
      })
    end

    pickers
      .new({}, {
        prompt_title = 'Jira Projects',
        finder = finders.new_table({
          results = project_entries,
          entry_maker = function(entry)
            return {
              value = entry,
              display = entry.display,
              ordinal = entry.display,
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local selection = action_state.get_selected_entry()
            if selection then
              -- Set as current project and list issues
              local project_key = selection.value.key
              utils.show_info('Selected project: ' .. project_key)
              cli.issue_list('-p' .. project_key)
            end
          end)
          return true
        end,
      })
      :find()
  end)
end

-- Quick filters
function M.show_my_issues()
  -- Check if default project exists
  local default_project = config.get('project_key') or config.get('default_project')
  local jql
  local title = 'My Issues'

  if default_project and default_project ~= '' then
    -- Include default project in the query using format_jql for safety
    local jql_parts = {
      { 'project', '=', default_project },
      { 'assignee', '=', 'currentUser()' },
    }
    jql = require('jira-nvim.api').format_jql(jql_parts)
    title = 'My Issues - Project: ' .. default_project
  else
    jql = 'assignee = currentUser()'
  end

  -- Add ordering
  jql = jql .. ' ORDER BY updated DESC'

  -- Use direct API search instead of constructing CLI-style parameters
  local api = require('jira-nvim.api')
  local utils = require('jira-nvim.utils')
  local ui = require('jira-nvim.ui')

  -- Execute in protected call to prevent blocking on errors
  local ok, result = pcall(function()
    -- Show loading indicator
    local spinner = utils.create_spinner('Loading my issues')

    -- Use coroutine to prevent blocking
    local co = coroutine.create(function()
      api.search_issues(jql, config.get('max_results'), function(err, data)
        spinner.stop()

        if err then
          utils.show_error('Error getting my issues: ' .. err)
          return
        end

        -- Check if we got issues from other projects despite filtering
        if default_project and default_project ~= '' then
          -- Filter results to ensure they match the project
          local filtered_issues = {}
          for _, issue in ipairs(data.issues or {}) do
            if issue.key:match('^' .. default_project .. '%-') then
              table.insert(filtered_issues, issue)
            end
          end

          -- Replace the issues array with our filtered version
          data.issues = filtered_issues
          data.total = #filtered_issues
        end

        local formatted_output = utils.parse_api_response(data, 'issues')
        ui.show_output(title, formatted_output)
      end)
    end)

    coroutine.resume(co)
  end)

  if not ok then
    utils.show_error('Error processing my issues: ' .. tostring(result))
  end
end

function M.show_issues_by_status(status)
  status = status or 'To Do'
  cli.issue_list('-s"' .. status .. '"')
end

function M.show_issues_by_priority(priority)
  priority = priority or 'High'
  cli.issue_list('-y"' .. priority .. '"')
end

-- Function to show recent issues
function M.show_recent_issues()
  -- Check if default project exists
  local default_project = config.get('project_key') or config.get('default_project')
  local jql
  local title = 'Recent Issues'

  if default_project and default_project ~= '' then
    -- Include default project in the query using format_jql for safety
    local jql_parts = {
      { 'project', '=', default_project },
      { 'created', '>=', '-7d' },
    }
    jql = require('jira-nvim.api').format_jql(jql_parts)
    title = 'Recent Issues - Project: ' .. default_project
  else
    jql = 'created >= -7d'
  end

  -- Add ordering
  jql = jql .. ' ORDER BY created DESC'

  -- Use direct API search instead of constructing CLI-style parameters
  local api = require('jira-nvim.api')
  local utils = require('jira-nvim.utils')
  local ui = require('jira-nvim.ui')

  -- Execute in protected call to prevent blocking on errors
  local ok, result = pcall(function()
    -- Show loading indicator
    local spinner = utils.create_spinner('Loading recent issues')

    -- Use coroutine to prevent blocking
    local co = coroutine.create(function()
      api.search_issues(jql, config.get('max_results'), function(err, data)
        spinner.stop()

        if err then
          utils.show_error('Error getting recent issues: ' .. err)
          return
        end

        local formatted_output = utils.parse_api_response(data, 'issues')
        ui.show_output(title, formatted_output)
      end)
    end)

    coroutine.resume(co)
  end)

  if not ok then
    utils.show_error('Error processing recent issues: ' .. tostring(result))
  end
end

-- Function to show high priority issues
function M.show_high_priority_issues()
  -- Check if default project exists
  local default_project = config.get('project_key') or config.get('default_project')
  local jql
  local title = 'High Priority Issues'

  if default_project and default_project ~= '' then
    -- Include default project in the query using format_jql for safety
    local jql_parts = {
      { 'project', '=', default_project },
      { 'priority', '=', 'High' },
    }
    jql = require('jira-nvim.api').format_jql(jql_parts)
    title = 'High Priority Issues - Project: ' .. default_project
  else
    jql = 'priority = High'
  end

  -- Add ordering
  jql = jql .. ' ORDER BY updated DESC'

  -- Use direct API search
  local api = require('jira-nvim.api')
  local utils = require('jira-nvim.utils')
  local ui = require('jira-nvim.ui')

  -- Execute in protected call to prevent blocking on errors
  local ok, result = pcall(function()
    -- Show loading indicator
    local spinner = utils.create_spinner('Loading high priority issues')

    -- Use coroutine to prevent blocking
    local co = coroutine.create(function()
      api.search_issues(jql, config.get('max_results'), function(err, data)
        spinner.stop()

        if err then
          utils.show_error('Error getting high priority issues: ' .. err)
          return
        end

        local formatted_output = utils.parse_api_response(data, 'issues')
        ui.show_output(title, formatted_output)
      end)
    end)

    coroutine.resume(co)
  end)

  if not ok then
    utils.show_error('Error processing high priority issues: ' .. tostring(result))
  end
end

-- Function to show unassigned issues
function M.show_unassigned_issues()
  -- Check if default project exists
  local default_project = config.get('project_key') or config.get('default_project')
  local jql
  local title = 'Unassigned Issues'

  if default_project and default_project ~= '' then
    -- Include default project in the query using format_jql for safety
    local jql_parts = {
      { 'project', '=', default_project },
      { 'assignee', 'IS EMPTY', nil },
    }
    jql = require('jira-nvim.api').format_jql(jql_parts)
    title = 'Unassigned Issues - Project: ' .. default_project
  else
    jql = 'assignee IS EMPTY'
  end

  -- Add ordering
  jql = jql .. ' ORDER BY updated DESC'

  -- Use direct API search
  local api = require('jira-nvim.api')
  local utils = require('jira-nvim.utils')
  local ui = require('jira-nvim.ui')

  -- Execute in protected call to prevent blocking on errors
  local ok, result = pcall(function()
    -- Show loading indicator
    local spinner = utils.create_spinner('Loading unassigned issues')

    -- Use coroutine to prevent blocking
    local co = coroutine.create(function()
      api.search_issues(jql, config.get('max_results'), function(err, data)
        spinner.stop()

        if err then
          utils.show_error('Error getting unassigned issues: ' .. err)
          return
        end

        local formatted_output = utils.parse_api_response(data, 'issues')
        ui.show_output(title, formatted_output)
      end)
    end)

    coroutine.resume(co)
  end)

  if not ok then
    utils.show_error('Error processing unassigned issues: ' .. tostring(result))
  end
end

-- Fuzzy search boards using telescope
function M.telescope_search_boards(project_key)
  if not has_telescope then
    utils.show_error('Telescope not available. Install telescope.nvim for fuzzy search.')
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  -- Show loading indicator
  local spinner = utils.create_spinner('Loading boards')

  -- Get boards (either all or for specific project)
  local api = require('jira-nvim.api')

  local fetch_func = function(callback)
    if project_key then
      api.get_project_boards(project_key, callback)
    else
      api.get_boards(callback)
    end
  end

  fetch_func(function(err, boards)
    spinner.stop()

    if err then
      utils.show_error('Error loading boards: ' .. err)
      return
    end

    if not boards or #boards == 0 then
      utils.show_info('No boards found')
      return
    end

    local board_entries = {}
    for _, board in ipairs(boards) do
      local project_name = ''
      if board.location and board.location.projectName then
        project_name = ' - ' .. board.location.projectName
      end

      table.insert(board_entries, {
        id = board.id,
        name = board.name,
        type = board.type,
        display = board.name .. ' (' .. board.type .. ')' .. project_name,
      })
    end

    pickers
      .new({}, {
        prompt_title = 'Jira Boards',
        finder = finders.new_table({
          results = board_entries,
          entry_maker = function(entry)
            return {
              value = entry,
              display = entry.display,
              ordinal = entry.display,
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local selection = action_state.get_selected_entry()
            if selection then
              -- Selected a board, give options
              local board_id = selection.value.id
              local board_name = selection.value.name

              vim.ui.select({ 'View Sprints', 'View Epics' }, {
                prompt = 'Action for board: ' .. board_name,
              }, function(choice)
                if choice == 'View Sprints' then
                  cli.sprint_list('-b' .. board_id)
                elseif choice == 'View Epics' then
                  cli.epic_list('-b' .. board_id)
                end
              end)
            end
          end)
          return true
        end,
      })
      :find()
  end)
end

return M
