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
  if not utils.is_jira_available() then
    callback('Jira CLI not found')
    return
  end
  
  local jira_cmd = config.get('jira_cmd')
  local full_cmd = jira_cmd .. ' me'
  
  vim.fn.jobstart({'sh', '-c', full_cmd}, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      local output = table.concat(data, '\n'):gsub('^%s*(.-)%s*$', '%1')
      if output and output ~= '' then
        user_cache.username = output
        user_cache.loaded = true
        user_cache.loading = false
        if callback then callback(nil, output) end
      end
    end,
    on_stderr = function(_, data)
      local error_msg = table.concat(data, '\n')
      user_cache.loading = false
      if callback then callback(error_msg, nil) end
    end,
    on_exit = function(_, code)
      user_cache.loading = false
      if code ~= 0 and callback then
        callback('Failed to get current user (exit code: ' .. code .. ')', nil)
      end
    end
  })
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