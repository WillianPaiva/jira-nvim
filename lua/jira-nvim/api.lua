local M = {}
local curl = require('plenary.curl')
local config = require('jira-nvim.config')
local utils = require('jira-nvim.utils')

-- Authentication state
local auth = {
  base_url = nil,
  email = nil,
  api_token = nil,
  auth_header = nil,
  auth_type = 'basic'  -- 'basic' or 'bearer'
}

-- Base API URL paths
local api_paths = {
  v3 = '/rest/api/3',
  v2 = '/rest/api/2',
  agile = '/rest/agile/1.0',
  agile_alternative = '/rest/agile/latest'  -- Fallback for some server instances
}

-- Initialize API connection
function M.setup()
  local base_url = config.get('jira_url')
  local email = config.get('jira_email')
  local api_token = config.get('jira_api_token')
  local auth_type = config.get('auth_type') or 'basic'

  if not base_url then
    utils.show_error('Jira URL missing. Please set jira_url in your config.')
    return false
  end
  
  if auth_type == 'basic' and (not email or not api_token) then
    utils.show_error('Basic authentication requires both email and API token.')
    return false
  end
  
  if auth_type == 'bearer' and not api_token then
    utils.show_error('Bearer authentication requires an API token.')
    return false
  end

  -- Store auth info
  auth.base_url = base_url
  auth.email = email
  auth.api_token = api_token
  auth.auth_type = auth_type
  
  -- Create authentication header based on auth type
  if auth_type == 'bearer' then
    auth.auth_header = 'Bearer ' .. api_token
  else 
    -- Basic auth (default)
    local auth_string = email .. ':' .. api_token
    auth.auth_header = 'Basic ' .. vim.fn.system('echo -n "' .. auth_string .. '" | base64 | tr -d "\n"')
  end
  
  -- Detect Jira server type (cloud vs. server)
  if base_url:match('atlassian.net') then
    auth.server_type = 'cloud'
  else
    auth.server_type = 'server'
  end
  
  -- Adjust API paths based on server type
  if auth.server_type == 'server' then
    api_paths.v3 = api_paths.v2  -- Fallback to v2 for server instances
  end

  return true
end

-- Generate a URL for the Jira UI
function M.get_browse_url(issue_key)
  if not auth.base_url then
    if not M.setup() then
      return nil
    end
  end
  
  return auth.base_url .. '/browse/' .. issue_key
end

-- Make API request
function M.request(method, endpoint, api_version, data, callback)
  if not auth.base_url then
    if not M.setup() then
      return
    end
  end

  -- Default to API v3 if not specified
  api_version = api_version or 'v3'
  local base_path = api_paths.v3
  
  if api_version == 'v2' then
    base_path = api_paths.v2
  elseif api_version == 'agile' then
    base_path = api_paths.agile
  end

  -- For server instances, make sure URL doesn't end with a slash
  local base_url = auth.base_url:gsub('/$', '')
  local url = base_url .. base_path .. endpoint

  local headers = {
    ['Authorization'] = auth.auth_header,
    ['Content-Type'] = 'application/json',
    ['Accept'] = 'application/json'
  }

  local opts = {
    headers = headers,
    timeout = 10000
  }

  if data then
    opts.body = vim.fn.json_encode(data)
  end

  local response

  if method == 'GET' then
    response = curl.get(url, opts)
  elseif method == 'POST' then
    response = curl.post(url, opts)
  elseif method == 'PUT' then
    response = curl.put(url, opts)
  elseif method == 'DELETE' then
    response = curl.delete(url, opts)
  else
    utils.show_error('Unsupported HTTP method: ' .. method)
    return
  end

  if response.status >= 400 then
    local err_msg = 'API Error: ' .. response.status
    if response.body then
      local success, body = pcall(vim.fn.json_decode, response.body)
      if success and body and body.errorMessages then
        err_msg = err_msg .. ' - ' .. table.concat(body.errorMessages, ', ')
      else
        err_msg = err_msg .. ' - ' .. response.body
      end
    end
    
    -- Special handling for specific error codes
    if response.status == 404 and method == 'GET' and api_version == 'v3' then
      -- Try falling back to v2 API for older Jira instances
      M.request(method, endpoint, 'v2', data, callback)
      return
    end
    
    callback(err_msg, nil)
  else
    local result = nil
    if response.body and response.body ~= '' then
      local success, decoded = pcall(vim.fn.json_decode, response.body)
      if success then
        result = decoded
      else
        callback('Failed to parse JSON response: ' .. response.body, nil)
        return
      end
    end
    callback(nil, result)
  end
end

-- API Endpoints

-- Get current user ("myself")
function M.get_current_user(callback)
  M.request('GET', '/myself', 'v3', nil, callback)
end

-- Get issue with rendered fields and transition options
function M.get_issue(issue_key, callback)
  M.request('GET', '/issue/' .. issue_key .. '?expand=renderedFields,transitions', 'v3', nil, callback)
end

-- URL encode a string (simpler version focused on Jira JQL needs)
function M.url_encode(str)
  if not str then return "" end
  local s = str:gsub(" ", "%%20")
  s = s:gsub("=", "%%3D")
  s = s:gsub("\"", "%%22")
  s = s:gsub("&", "%%26")
  s = s:gsub("%+", "%%2B")
  s = s:gsub("<", "%%3C")
  s = s:gsub(">", "%%3E")
  return s
end

-- Format JQL query safely
function M.format_jql(jql_parts, combine)
  local formatted = {}
  combine = combine or 'AND'
  
  for _, part in ipairs(jql_parts) do
    local field = part[1]
    local operator = part[2]
    local value = part[3]
    
    -- Handle special operators like IS EMPTY, IS NOT EMPTY
    if operator == 'IS EMPTY' or operator == 'IS NOT EMPTY' then
      table.insert(formatted, field .. ' ' .. operator)
    -- Handle IN operators with arrays
    elseif operator == 'IN' and type(value) == 'table' then
      local values = {}
      for _, v in ipairs(value) do
        if v:match('[%s,]') then
          table.insert(values, '"' .. v .. '"')
        else
          table.insert(values, v)
        end
      end
      table.insert(formatted, field .. ' IN (' .. table.concat(values, ',') .. ')')
    -- Handle operators like <, >, <=, >=
    elseif operator:match('^[<>=]') then
      if type(value) == 'string' and value:match('[%s,]') then
        table.insert(formatted, field .. ' ' .. operator .. ' "' .. value .. '"')
      else
        table.insert(formatted, field .. ' ' .. operator .. ' ' .. value)
      end
    -- Standard operators (=, !=, etc.)
    else
      if type(value) == 'string' then
        if value:match('[%s,]') then
          table.insert(formatted, field .. ' ' .. operator .. ' "' .. value .. '"')
        else
          table.insert(formatted, field .. ' ' .. operator .. ' ' .. value)
        end
      else
        table.insert(formatted, field .. ' ' .. operator .. ' ' .. tostring(value))
      end
    end
  end
  
  return table.concat(formatted, ' ' .. combine .. ' ')
end

-- Search issues with JQL
function M.search_issues(jql, max_results, callback)
  max_results = max_results or 50
  local encoded_jql = M.url_encode(jql)
  local params = '?jql=' .. encoded_jql
  params = params .. '&expand=renderedFields'
  params = params .. '&maxResults=' .. max_results
  M.request('GET', '/search' .. params, 'v2', nil, callback)
end

-- Create issue
function M.create_issue(project_key, issue_type, summary, description, additional_fields, callback)
  local data = {
    fields = {
      project = { key = project_key },
      issuetype = { name = issue_type },
      summary = summary
    }
  }
  
  -- Add description if provided
  if description then
    data.fields.description = {
      type = 'doc',
      version = 1,
      content = {
        {
          type = 'paragraph',
          content = {
            {
              type = 'text',
              text = description
            }
          }
        }
      }
    }
  end
  
  -- Add any additional fields
  if additional_fields then
    for k, v in pairs(additional_fields) do
      data.fields[k] = v
    end
  end
  
  M.request('POST', '/issue', 'v3', data, callback)
end

-- Get available transitions for an issue
function M.get_transitions(issue_key, callback)
  M.request('GET', '/issue/' .. issue_key .. '/transitions', 'v3', nil, callback)
end

-- Transition issue
function M.transition_issue(issue_key, transition_id, fields, comment, callback)
  local data = {
    transition = { id = transition_id }
  }
  
  if fields then
    data.fields = fields
  end
  
  if comment then
    data.update = {
      comment = {
        {
          add = {
            body = {
              type = 'doc',
              version = 1,
              content = {
                {
                  type = 'paragraph',
                  content = {
                    {
                      type = 'text',
                      text = comment
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  end
  
  M.request('POST', '/issue/' .. issue_key .. '/transitions', 'v3', data, callback)
end

-- Add comment to issue
function M.add_comment(issue_key, comment, callback)
  local data = {
    body = {
      type = 'doc',
      version = 1,
      content = {
        {
          type = 'paragraph',
          content = {
            {
              type = 'text',
              text = comment
            }
          }
        }
      }
    }
  }
  
  M.request('POST', '/issue/' .. issue_key .. '/comment', 'v3', data, callback)
end

-- Get comments for an issue
function M.get_comments(issue_key, max_results, callback)
  max_results = max_results or 10
  local params = '?maxResults=' .. max_results .. '&orderBy=-created'
  M.request('GET', '/issue/' .. issue_key .. '/comment' .. params, 'v3', nil, callback)
end

-- Assign issue to user
function M.assign_issue(issue_key, account_id, callback)
  local data = {}
  
  -- If account_id is 'none', set to null for API (unassign)
  -- If account_id is nil or empty, assign to default
  if account_id == 'none' then
    data.accountId = vim.NIL
  elseif account_id and account_id ~= '' then
    data.accountId = account_id
  end
  
  M.request('PUT', '/issue/' .. issue_key .. '/assignee', 'v3', data, callback)
end

-- Add watcher to issue
function M.add_watcher(issue_key, account_id, callback)
  M.request('POST', '/issue/' .. issue_key .. '/watchers', 'v3', '"' .. account_id .. '"', callback)
end

-- Get all projects
function M.get_projects(callback)
  -- First try with v3 API, fall back to v2 if needed
  M.request('GET', '/project', 'v2', nil, function(err, data)
    if err then
      callback(err, nil)
    else
      -- Filter out archived projects by default if that field exists
      local active_projects = {}
      for _, project in ipairs(data) do
        if project.archived == nil or not project.archived then
          table.insert(active_projects, project)
        end
      end
      callback(nil, active_projects)
    end
  end)
end

-- Get project by key
function M.get_project(project_key, callback)
  M.request('GET', '/project/' .. project_key, 'v3', nil, callback)
end

-- Get all boards
function M.get_boards(callback)
  -- First try with the standard agile endpoint
  M.request('GET', '/board', 'agile', nil, function(err, data)
    if err then
      -- If that fails, try with the alternative endpoint
      if err:match('API Error: 404') then
        -- Use alternative agile path
        local url = auth.base_url:gsub('/$', '') .. api_paths.agile_alternative .. '/board'
        local headers = {
          ['Authorization'] = auth.auth_header,
          ['Content-Type'] = 'application/json',
          ['Accept'] = 'application/json'
        }
        
        local response = curl.get(url, {
          headers = headers,
          timeout = 10000
        })
        
        if response.status >= 400 then
          callback('API Error: ' .. response.status .. ' - Could not retrieve boards', nil)
        else
          local success, result = pcall(vim.fn.json_decode, response.body)
          if success and result then
            if result.values then
              callback(nil, result.values)
            else
              callback(nil, {}) -- Return empty array if no values field
            end
          else
            callback('Failed to parse board data', nil)
          end
        end
      else
        callback(err, nil)
      end
    else
      if data.values then
        callback(nil, data.values)
      else
        callback(nil, {}) -- Return empty array if no values field
      end
    end
  end)
end

-- Get boards for a specific project
function M.get_project_boards(project_key, callback)
  local params = '?projectKeyOrId=' .. project_key
  
  -- First try with the standard agile endpoint
  M.request('GET', '/board' .. params, 'agile', nil, function(err, data)
    if err then
      -- If that fails, try with the alternative endpoint
      if err:match('API Error: 404') then
        -- Use alternative agile path
        local url = auth.base_url:gsub('/$', '') .. api_paths.agile_alternative .. '/board' .. params
        local headers = {
          ['Authorization'] = auth.auth_header,
          ['Content-Type'] = 'application/json',
          ['Accept'] = 'application/json'
        }
        
        local response = curl.get(url, {
          headers = headers,
          timeout = 10000
        })
        
        if response.status >= 400 then
          callback('API Error: ' .. response.status .. ' - Could not retrieve project boards', nil)
        else
          local success, result = pcall(vim.fn.json_decode, response.body)
          if success and result then
            if result.values then
              callback(nil, result.values)
            else
              callback(nil, {}) -- Return empty array if no values field
            end
          else
            callback('Failed to parse board data', nil)
          end
        end
      else
        callback(err, nil)
      end
    else
      if data.values then
        callback(nil, data.values)
      else
        callback(nil, {}) -- Return empty array if no values field
      end
    end
  end)
end

-- Get sprints for a board
function M.get_sprints(board_id, callback)
  M.request('GET', '/board/' .. board_id .. '/sprint', 'agile', nil, function(err, data)
    if err then
      -- If that fails, try with the alternative endpoint
      if err:match('API Error: 404') then
        -- Use alternative agile path
        local url = auth.base_url:gsub('/$', '') .. api_paths.agile_alternative .. '/board/' .. board_id .. '/sprint'
        local headers = {
          ['Authorization'] = auth.auth_header,
          ['Content-Type'] = 'application/json',
          ['Accept'] = 'application/json'
        }
        
        local response = curl.get(url, {
          headers = headers,
          timeout = 10000
        })
        
        if response.status >= 400 then
          callback('API Error: ' .. response.status .. ' - Could not retrieve sprints', nil)
        else
          local success, result = pcall(vim.fn.json_decode, response.body)
          if success and result then
            callback(nil, result)
          else
            callback('Failed to parse sprint data', nil)
          end
        end
      else
        callback(err, nil)
      end
    else
      callback(nil, data)
    end
  end)
end

-- Get active sprint for a board
function M.get_active_sprint(board_id, callback)
  M.request('GET', '/board/' .. board_id .. '/sprint?state=active', 'agile', nil, function(err, data)
    if err then
      -- If that fails, try with the alternative endpoint
      if err:match('API Error: 404') then
        -- Use alternative agile path
        local url = auth.base_url:gsub('/$', '') .. api_paths.agile_alternative .. '/board/' .. board_id .. '/sprint?state=active'
        local headers = {
          ['Authorization'] = auth.auth_header,
          ['Content-Type'] = 'application/json',
          ['Accept'] = 'application/json'
        }
        
        local response = curl.get(url, {
          headers = headers,
          timeout = 10000
        })
        
        if response.status >= 400 then
          callback('API Error: ' .. response.status .. ' - Could not retrieve active sprint', nil)
        else
          local success, result = pcall(vim.fn.json_decode, response.body)
          if success and result then
            callback(nil, result)
          else
            callback('Failed to parse sprint data', nil)
          end
        end
      else
        callback(err, nil)
      end
    else
      callback(nil, data)
    end
  end)
end

-- Get epics for a board
function M.get_epics(board_id, callback)
  M.request('GET', '/board/' .. board_id .. '/epic', 'agile', nil, function(err, data)
    if err then
      -- If that fails, try with the alternative endpoint
      if err:match('API Error: 404') then
        -- Use alternative agile path
        local url = auth.base_url:gsub('/$', '') .. api_paths.agile_alternative .. '/board/' .. board_id .. '/epic'
        local headers = {
          ['Authorization'] = auth.auth_header,
          ['Content-Type'] = 'application/json',
          ['Accept'] = 'application/json'
        }
        
        local response = curl.get(url, {
          headers = headers,
          timeout = 10000
        })
        
        if response.status >= 400 then
          callback('API Error: ' .. response.status .. ' - Could not retrieve epics', nil)
        else
          local success, result = pcall(vim.fn.json_decode, response.body)
          if success and result then
            if result.values then
              callback(nil, result.values)
            else
              callback(nil, {})
            end
          else
            callback('Failed to parse epics data', nil)
          end
        end
      else
        callback(err, nil)
      end
    else
      if data.values then
        callback(nil, data.values)
      else
        callback(nil, {})
      end
    end
  end)
end

-- Get issue types for a project
function M.get_issue_types(project_id, callback)
  M.request('GET', '/project/' .. project_id .. '/issueTypes', 'v3', nil, callback)
end

-- Get issue metadata (for field information when creating issues)
function M.get_create_meta(project_key, issue_type_id, callback)
  local params = '?projectKeys=' .. project_key
  
  if issue_type_id then
    params = params .. '&issuetypeIds=' .. issue_type_id
  end
  
  params = params .. '&expand=projects.issuetypes.fields'
  
  M.request('GET', '/issue/createmeta' .. params, 'v3', nil, callback)
end

-- Find users (for assignee selection)
function M.find_users(query, callback)
  local params = '?query=' .. vim.fn.escape(query, '&')
  M.request('GET', '/user/search' .. params, 'v3', nil, callback)
end

-- Format API responses for display
function M.format_issue_for_display(issue)
  local result = {}
  
  -- Basic info
  table.insert(result, '🎫 ' .. issue.key .. ' - ' .. issue.fields.summary)
  table.insert(result, '')
  
  -- Status and type
  table.insert(result, '📊 Type: ' .. issue.fields.issuetype.name)
  table.insert(result, '📊 Status: ' .. issue.fields.status.name)
  table.insert(result, '📊 Priority: ' .. issue.fields.priority.name)
  
  -- People
  if issue.fields.assignee and type(issue.fields.assignee) == 'table' and issue.fields.assignee.displayName then
    table.insert(result, '👤 Assignee: ' .. issue.fields.assignee.displayName)
  else
    table.insert(result, '👤 Assignee: Unassigned')
  end
  
  -- Reporter (might also be missing or formatted differently)
  if issue.fields.reporter and type(issue.fields.reporter) == 'table' and issue.fields.reporter.displayName then
    table.insert(result, '👤 Reporter: ' .. issue.fields.reporter.displayName)
  else
    table.insert(result, '👤 Reporter: Unknown')
  end
  
  -- Dates
  table.insert(result, '📅 Created: ' .. issue.fields.created:sub(1, 10))
  if issue.fields.updated then
    table.insert(result, '📅 Updated: ' .. issue.fields.updated:sub(1, 10))
  end
  
  -- Description
  table.insert(result, '')
  table.insert(result, '📝 Description:')
  
  if issue.renderedFields and issue.renderedFields.description then
    -- Add the rendered HTML description
    local description_lines = vim.split(issue.renderedFields.description, '\n')
    for _, line in ipairs(description_lines) do
      table.insert(result, '  ' .. line)
    end
  elseif issue.fields.description then
    -- Try to handle ADF document format
    if type(issue.fields.description) == 'table' and issue.fields.description.content then
      for _, content in ipairs(issue.fields.description.content) do
        if content.content then
          for _, text_item in ipairs(content.content) do
            if text_item.text then
              table.insert(result, '  ' .. text_item.text)
            end
          end
        end
      end
    elseif type(issue.fields.description) == 'string' then
      -- Plain text description
      table.insert(result, '  ' .. issue.fields.description)
    else
      table.insert(result, '  No description provided')
    end
  else
    table.insert(result, '  No description provided')
  end
  
  -- Comments if available
  if issue.fields.comment and issue.fields.comment.comments and #issue.fields.comment.comments > 0 then
    table.insert(result, '')
    table.insert(result, '💬 Comments (' .. issue.fields.comment.total .. '):') 
    
    for i, comment in ipairs(issue.fields.comment.comments) do
      table.insert(result, '')
      table.insert(result, '  ➤ ' .. comment.author.displayName .. ' - ' .. comment.created:sub(1, 10))
      
      -- Try to handle ADF document format
      if type(comment.body) == 'table' and comment.body.content then
        for _, content in ipairs(comment.body.content) do
          if content.content then
            for _, text_item in ipairs(content.content) do
              if text_item.text then
                table.insert(result, '    ' .. text_item.text)
              end
            end
          end
        end
      elseif type(comment.body) == 'string' then
        -- Plain text
        table.insert(result, '    ' .. comment.body)
      end
    end
  end
  
  return table.concat(result, '\n')
end

-- Format search results for display
function M.format_search_results(search_results)
  local result = {}
  
  table.insert(result, 'Found ' .. search_results.total .. ' issues')
  table.insert(result, string.rep('-', 40))
  table.insert(result, '')
  
  for _, issue in ipairs(search_results.issues) do
    local status_icon = '⏳'
    if issue.fields.status.name:match('In Progress') then
      status_icon = '🔄'
    elseif issue.fields.status.name:match('Done') then
      status_icon = '✅'
    elseif issue.fields.status.name:match('Closed') or issue.fields.status.name:match('Resolved') then
      status_icon = '🔒'
    end
    
    local type_icon = '📋'
    if issue.fields.issuetype.name:match('Bug') then
      type_icon = '🐛'
    elseif issue.fields.issuetype.name:match('Epic') then
      type_icon = '🎯'
    elseif issue.fields.issuetype.name:match('Story') then
      type_icon = '📖'
    elseif issue.fields.issuetype.name:match('Sub') then
      type_icon = '📝'
    end
    
    local line = string.format('%s %s | %s %s | %s',
      type_icon, issue.fields.issuetype.name,
      status_icon, issue.fields.status.name,
      issue.key)
    
    if issue.fields.assignee then
      -- Check if assignee is a table with displayName
      if type(issue.fields.assignee) == 'table' and issue.fields.assignee.displayName then
        line = line .. ' | 👤 ' .. issue.fields.assignee.displayName
      else
        -- Handle case where assignee might be formatted differently
        line = line .. ' | 👤 Assigned'
      end
    else
      line = line .. ' | 👤 Unassigned'
    end
    
    line = line .. ' | ' .. issue.fields.summary
    
    table.insert(result, line)
  end
  
  return table.concat(result, '\n')
end

return M