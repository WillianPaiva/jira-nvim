local M = {}

local api = require('jira-nvim.api')
local config = require('jira-nvim.config')
local ui = require('jira-nvim.ui')
local utils = require('jira-nvim.utils')
local user = require('jira-nvim.user')

-- Dashboard sections
local sections = {
  {
    title = "My Issues",
    fetch = function(callback)
      local jql = "assignee = currentUser() ORDER BY updated DESC"
      api.search_issues(jql, 10, callback)
    end,
    format = function(data)
      return M.format_issue_section(data, "My Assigned Issues")
    end
  },
  {
    title = "Current Sprint",
    fetch = function(callback)
      local board_id = config.get('default_board')
      if not board_id then
        callback("No default board configured. Use :JiraSetDefaultBoard to set one.", nil)
        return
      end

      api.get_active_sprint(board_id, function(err, sprint_data)
        if err then
          callback(err, nil)
          return
        end

        if not sprint_data or not sprint_data.values or #sprint_data.values == 0 then
          callback("No active sprint found.", nil)
          return
        end

        local sprint_id = sprint_data.values[1].id
        local jql = "sprint = " .. sprint_id .. " ORDER BY status ASC, priority DESC"
        api.search_issues(jql, 10, callback)
      end)
    end,
    format = function(data)
      return M.format_issue_section(data, "Current Sprint Issues")
    end
  },
  {
    title = "Recent Activity",
    fetch = function(callback)
      local jql = "updatedDate >= -7d AND (assignee = currentUser() OR reporter = currentUser() OR watcher = currentUser()) ORDER BY updated DESC"
      api.search_issues(jql, 10, callback)
    end,
    format = function(data)
      return M.format_issue_section(data, "Recent Activity (Last 7 Days)")
    end
  },
  {
    title = "High Priority",
    fetch = function(callback)
      local jql = "priority in (Highest, High) AND resolution = Unresolved ORDER BY priority DESC, updated DESC"
      api.search_issues(jql, 10, callback)
    end,
    format = function(data)
      return M.format_issue_section(data, "High Priority Issues")
    end
  }
}

-- Format a section of issues
function M.format_issue_section(data, title)
  if not data or not data.issues then
    return { title .. ": No issues found" }
  end

  local result = { title .. " (" .. #data.issues .. " of " .. data.total .. ")" }
  table.insert(result, string.rep('-', #result[1]))
  table.insert(result, "")

  for i, issue in ipairs(data.issues) do
    local status_icon = '⏳'
    if issue.fields.status.name:match('In Progress') then
      status_icon = '🔄'
    elseif issue.fields.status.name:match('Done') or issue.fields.status.name:match('Resolved') then
      status_icon = '✅'
    elseif issue.fields.status.name:match('Closed') then
      status_icon = '🔒'
    end

    local priority_icon = '🔵'
    if issue.fields.priority.name:match('Highest') then
      priority_icon = '🔴'
    elseif issue.fields.priority.name:match('High') then
      priority_icon = '🟠'
    elseif issue.fields.priority.name:match('Medium') then
      priority_icon = '🟡'
    elseif issue.fields.priority.name:match('Low') then
      priority_icon = '🟢'
    end

    local assignee = "Unassigned"
    if issue.fields.assignee and type(issue.fields.assignee) == "table" and issue.fields.assignee.displayName then
      assignee = issue.fields.assignee.displayName
    end

    local line = string.format("%s %s | %s | %s | %s | %s",
      priority_icon,
      issue.key,
      status_icon .. ' ' .. issue.fields.status.name,
      issue.fields.issuetype.name,
      "👤 " .. assignee,
      issue.fields.summary
    )
    table.insert(result, line)
  end

  return result
end

-- Show the dashboard
function M.show_dashboard()
  -- Check if we're connected to Jira
  if not api.setup() then
    utils.show_error('Jira API not properly configured. Run :JiraSetup first.')
    return
  end

  utils.show_info('Loading Jira dashboard...')
  
  local dashboard_content = {}
  local loaded_sections = 0
  local total_sections = #sections

  -- Function to check if all sections are loaded and display the dashboard
  local function check_complete()
    if loaded_sections == total_sections then
      local content = {"🎯 Jira Dashboard", "=================", ""}
      
      for _, section_content in ipairs(dashboard_content) do
        for _, line in ipairs(section_content) do
          table.insert(content, line)
        end
        table.insert(content, "")
        table.insert(content, "")
      end

      ui.show_output('Jira Dashboard', table.concat(content, '\n'))
    end
  end

  -- Process each section
  for i, section in ipairs(sections) do
    dashboard_content[i] = {}
    
    section.fetch(function(err, data)
      if err then
        dashboard_content[i] = {section.title .. ": Error - " .. err}
      else
        dashboard_content[i] = section.format(data)
      end
      
      loaded_sections = loaded_sections + 1
      check_complete()
    end)
  end
end

-- Show personal stats dashboard
function M.show_stats()
  -- Check if we're connected to Jira
  if not api.setup() then
    utils.show_error('Jira API not properly configured. Run :JiraSetup first.')
    return
  end

  utils.show_info('Loading Jira stats...')

  -- Get the user info first
  api.get_current_user(function(err, user_data)
    if err then
      utils.show_error('Failed to get user info: ' .. err)
      return
    end
    
    -- Ensure user_data is properly initialized
    if not user_data or type(user_data) ~= "table" then
      utils.show_error('Invalid user data received from Jira API')
      return
    end

    -- Query for various statistics
    local stats = {}
    local loaded_stats = 0
    local total_stats = 5

    -- Function to check if all stats are loaded and display
    local function check_complete()
      if loaded_stats == total_stats then
        -- Ensure we have a valid display name
        local display_name = user_data.displayName or "Unknown User"
        
        local content = {
          "📊 Jira Personal Statistics for " .. display_name,
          "=================================================",
          "",
          "👤 User: " .. display_name .. " (" .. (user_data.emailAddress or "No email") .. ")",
          -- Add account ID only if available
          user_data.accountId and ("🔑 Account ID: " .. user_data.accountId) or "🔑 Account ID: Not available",
          ""
        }

        for _, stat in ipairs(stats) do
          table.insert(content, stat.title .. ": " .. stat.value)
        end

        ui.show_output('Jira Stats', table.concat(content, '\n'))
      end
    end

    -- Assigned issues
    api.search_issues("assignee = currentUser() AND resolution = Unresolved", 1, function(err, data)
      if not err and data then
        table.insert(stats, {title = "🎯 Assigned Issues", value = data.total})
      else
        table.insert(stats, {title = "🎯 Assigned Issues", value = "Error"})
      end
      loaded_stats = loaded_stats + 1
      check_complete()
    end)

    -- Issues created this month
    api.search_issues("reporter = currentUser() AND created >= startOfMonth()", 1, function(err, data)
      if not err and data then
        table.insert(stats, {title = "✨ Created This Month", value = data.total})
      else
        table.insert(stats, {title = "✨ Created This Month", value = "Error"})
      end
      loaded_stats = loaded_stats + 1
      check_complete()
    end)

    -- Issues resolved this month
    api.search_issues("assignee = currentUser() AND resolved >= startOfMonth()", 1, function(err, data)
      if not err and data then
        table.insert(stats, {title = "✅ Resolved This Month", value = data.total})
      else
        table.insert(stats, {title = "✅ Resolved This Month", value = "Error"})
      end
      loaded_stats = loaded_stats + 1
      check_complete()
    end)

    -- Issues in current sprint
    local board_id = config.get('default_board')
    if board_id then
      api.get_active_sprint(board_id, function(err, sprint_data)
        if err or not sprint_data or not sprint_data.values or #sprint_data.values == 0 then
          table.insert(stats, {title = "🏃 Current Sprint Issues", value = "No active sprint"})
          loaded_stats = loaded_stats + 1
          check_complete()
          return
        end

        local sprint_id = sprint_data.values[1].id
        api.search_issues("sprint = " .. sprint_id .. " AND assignee = currentUser()", 1, function(err, data)
          if not err and data then
            table.insert(stats, {title = "🏃 Current Sprint Issues", value = data.total})
          else
            table.insert(stats, {title = "🏃 Current Sprint Issues", value = "Error"})
          end
          loaded_stats = loaded_stats + 1
          check_complete()
        end)
      end)
    else
      table.insert(stats, {title = "🏃 Current Sprint Issues", value = "No default board"})
      loaded_stats = loaded_stats + 1
      check_complete()
    end

    -- High priority issues
    api.search_issues("assignee = currentUser() AND priority in (Highest, High) AND resolution = Unresolved", 1, function(err, data)
      if not err and data then
        table.insert(stats, {title = "🔥 High Priority Issues", value = data.total})
      else
        table.insert(stats, {title = "🔥 High Priority Issues", value = "Error"})
      end
      loaded_stats = loaded_stats + 1
      check_complete()
    end)
  end)
end

return M