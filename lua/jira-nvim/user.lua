local M = {}

local config = require('jira-nvim.config')
local utils = require('jira-nvim.utils')

-- Cache for the current user
local user_cache = {
  username = nil,
  loaded = false,
  loading = false
}

local function fetch_current_user(callback)
  if not utils.is_api_available() then
    callback('Jira API not configured')
    return
  end
  
  local api = require('jira-nvim.api')
  
  api.get_current_user(function(err, data)
    if err then
      user_cache.loading = false
      if callback then callback(err, nil) end
      return
    end
    
    if data and data.displayName then
      user_cache.username = data.displayName
      user_cache.email = data.emailAddress
      user_cache.account_id = data.accountId
      user_cache.loaded = true
      user_cache.loading = false
      if callback then callback(nil, data.displayName) end
    else
      user_cache.loading = false
      if callback then callback('Invalid user data received', nil) end
    end
  end)
end

function M.get_current_user(callback)
  if user_cache.loaded and user_cache.username then
    if callback then callback(nil, user_cache.username) end
    return user_cache.username
  end
  
  if user_cache.loading then
    -- Already loading, just wait and callback when done
    vim.defer_fn(function()
      M.get_current_user(callback)
    end, 100)
    return nil
  end
  
  user_cache.loading = true
  fetch_current_user(callback)
  return nil
end

function M.get_cached_user()
  return user_cache.username
end

function M.is_loaded()
  return user_cache.loaded
end

function M.init()
  M.get_current_user(function(err, username)
    if err then
      utils.show_warning('Could not fetch current user: ' .. err)
    else
      utils.show_info('Logged in as: ' .. username)
    end
  end)
end

-- Replace $(jira me) patterns with actual username
function M.expand_user_patterns(text)
  if not text then return text end
  
  local username = M.get_cached_user()
  if username then
    return text:gsub('%$%(jira me%)', username)
  end
  
  return text
end

return M