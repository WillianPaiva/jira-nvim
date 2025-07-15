local M = {}

local utils = require('jira-nvim.utils')
local ui = require('jira-nvim.ui')

-- Default cache settings
local cache_settings = {
  enabled = true,
  ttl = 300, -- 5 minutes time-to-live
  max_size = 100, -- Maximum cache entries
}

-- In-memory cache stores
M.caches = {
  issues = {}, -- Cache for issue data
  projects = {}, -- Cache for project data
  users = {}, -- Cache for user data
  boards = {}, -- Cache for board data
  sprints = {}, -- Cache for sprint data
  search = {}, -- Cache for search results
}

-- Cache metadata
M.metadata = {
  issues = {
    hits = 0,
    misses = 0,
    size = 0,
  },
  projects = {
    hits = 0,
    misses = 0,
    size = 0,
  },
  users = {
    hits = 0,
    misses = 0,
    size = 0,
  },
  boards = {
    hits = 0,
    misses = 0,
    size = 0,
  },
  sprints = {
    hits = 0,
    misses = 0,
    size = 0,
  },
  search = {
    hits = 0,
    misses = 0,
    size = 0,
  },
}

-- Persist cache to disk
function M.save_cache()
  if not cache_settings.enabled then
    return false
  end

  local config_dir = vim.fn.stdpath('cache') .. '/jira-nvim'

  -- Create directory if it doesn't exist
  if vim.fn.isdirectory(config_dir) == 0 then
    vim.fn.mkdir(config_dir, 'p')
  end

  -- Save each cache type separately
  for cache_type, cache_data in pairs(M.caches) do
    -- Filter out expired entries
    local cleaned_cache = {}
    local now = os.time()

    for key, entry in pairs(cache_data) do
      if entry.expires > now then
        cleaned_cache[key] = entry
      end
    end

    -- Write to file
    local file_path = config_dir .. '/' .. cache_type .. '.cache'
    local f = io.open(file_path, 'w')
    if f then
      f:write(vim.fn.json_encode(cleaned_cache))
      f:close()
    end
  end

  return true
end

-- Load cache from disk
function M.load_cache()
  if not cache_settings.enabled then
    return false
  end

  local config_dir = vim.fn.stdpath('cache') .. '/jira-nvim'

  -- Check if cache directory exists
  if vim.fn.isdirectory(config_dir) == 0 then
    return false
  end

  -- Load each cache type
  for cache_type, _ in pairs(M.caches) do
    local file_path = config_dir .. '/' .. cache_type .. '.cache'

    if vim.fn.filereadable(file_path) == 1 then
      local f = io.open(file_path, 'r')
      if f then
        local content = f:read('*all')
        f:close()

        if content and content ~= '' then
          local success, data = pcall(vim.fn.json_decode, content)
          if success and type(data) == 'table' then
            -- Filter out expired entries
            local now = os.time()
            local count = 0

            for key, entry in pairs(data) do
              if entry.expires > now then
                M.caches[cache_type][key] = entry
                count = count + 1
              end
            end

            M.metadata[cache_type].size = count
          end
        end
      end
    end
  end

  return true
end

-- Get item from cache
function M.get(cache_type, key)
  if not cache_settings.enabled or not M.caches[cache_type] then
    return nil
  end

  local entry = M.caches[cache_type][key]

  if not entry then
    M.metadata[cache_type].misses = M.metadata[cache_type].misses + 1
    return nil
  end

  -- Check if entry is expired
  local now = os.time()
  if entry.expires <= now then
    M.caches[cache_type][key] = nil
    M.metadata[cache_type].size = M.metadata[cache_type].size - 1
    M.metadata[cache_type].misses = M.metadata[cache_type].misses + 1
    return nil
  end

  -- Update entry access time and extend TTL
  entry.accessed = now
  entry.expires = now + cache_settings.ttl
  M.metadata[cache_type].hits = M.metadata[cache_type].hits + 1

  return entry.data
end

-- Set item in cache
function M.set(cache_type, key, data)
  if not cache_settings.enabled or not M.caches[cache_type] then
    return false
  end

  local now = os.time()

  -- Check if we need to prune the cache
  if M.metadata[cache_type].size >= cache_settings.max_size then
    M.prune(cache_type)
  end

  -- Add entry to cache
  M.caches[cache_type][key] = {
    data = data,
    created = now,
    accessed = now,
    expires = now + cache_settings.ttl,
  }

  M.metadata[cache_type].size = M.metadata[cache_type].size + 1

  -- Periodically save cache (every 10 sets)
  if (M.metadata[cache_type].hits + M.metadata[cache_type].misses) % 10 == 0 then
    vim.defer_fn(function()
      M.save_cache()
    end, 1000)
  end

  return true
end

-- Remove item from cache
function M.remove(cache_type, key)
  if not cache_settings.enabled or not M.caches[cache_type] then
    return false
  end

  if M.caches[cache_type][key] then
    M.caches[cache_type][key] = nil
    M.metadata[cache_type].size = M.metadata[cache_type].size - 1
    return true
  end

  return false
end

-- Clear entire cache
function M.clear(cache_type)
  if not cache_type then
    -- Clear all caches
    for type, _ in pairs(M.caches) do
      M.caches[type] = {}
      M.metadata[type].size = 0
    end
  else
    -- Clear specific cache
    if M.caches[cache_type] then
      M.caches[cache_type] = {}
      M.metadata[cache_type].size = 0
    end
  end

  -- Save empty caches
  M.save_cache()

  return true
end

-- Prune old entries from cache
function M.prune(cache_type)
  if not cache_settings.enabled or not M.caches[cache_type] then
    return false
  end

  -- Get all entries with their access time
  local entries = {}
  for key, entry in pairs(M.caches[cache_type]) do
    table.insert(entries, { key = key, accessed = entry.accessed })
  end

  -- Sort by access time (oldest first)
  table.sort(entries, function(a, b)
    return a.accessed < b.accessed
  end)

  -- Remove oldest entries until we're under 80% capacity
  local target_size = math.floor(cache_settings.max_size * 0.8)
  local removed = 0

  while M.metadata[cache_type].size > target_size and removed < #entries do
    removed = removed + 1
    local key = entries[removed].key
    M.caches[cache_type][key] = nil
    M.metadata[cache_type].size = M.metadata[cache_type].size - 1
  end

  return removed
end

-- Configure cache settings
function M.configure(options)
  if options then
    for k, v in pairs(options) do
      cache_settings[k] = v
    end
  end
end

-- Get cache statistics
function M.get_stats()
  local stats = {
    settings = cache_settings,
    metadata = M.metadata,
  }

  -- Calculate hit rate for each cache
  for cache_type, meta in pairs(M.metadata) do
    local total = meta.hits + meta.misses
    meta.hit_rate = total > 0 and (meta.hits / total) * 100 or 0
  end

  return stats
end

-- Show cache statistics
function M.show_stats()
  local stats = M.get_stats()
  local lines = {}

  table.insert(lines, '📊 Jira Cache Statistics')
  table.insert(lines, '======================')
  table.insert(lines, '')

  table.insert(lines, string.format('Cache Enabled: %s', stats.settings.enabled and 'Yes' or 'No'))
  table.insert(lines, string.format('TTL: %s seconds', stats.settings.ttl))
  table.insert(lines, string.format('Max Size: %s entries per cache', stats.settings.max_size))
  table.insert(lines, '')

  -- Header
  table.insert(lines, string.format('%-10s %-8s %-8s %-8s %-10s', 'Cache', 'Size', 'Hits', 'Misses', 'Hit Rate'))
  table.insert(lines, string.rep('-', 50))

  -- Rows
  for cache_type, meta in pairs(stats.metadata) do
    table.insert(
      lines,
      string.format('%-10s %-8d %-8d %-8d %-10.1f%%', cache_type, meta.size, meta.hits, meta.misses, meta.hit_rate)
    )
  end

  ui.show_output('Cache Statistics', table.concat(lines, '\n'))
end

-- Wrap an API function with caching
function M.wrap(cache_type, get_key_fn, api_fn)
  return function(...)
    local args = { ... }
    local callback = args[#args]

    -- Check if last argument is a function (callback)
    if type(callback) ~= 'function' then
      -- If not a callback, just call the original function
      return api_fn(...)
    end

    -- Generate cache key from arguments
    local key = get_key_fn(...)

    -- Check cache
    local cached = M.get(cache_type, key)
    if cached then
      -- Return cached data
      return vim.schedule(function()
        callback(nil, cached)
      end)
    end

    -- Modify the callback to cache the result
    args[#args] = function(err, data)
      if not err and data then
        M.set(cache_type, key, data)
      end
      callback(err, data)
    end

    -- Call the original function with modified callback
    return api_fn(unpack(args))
  end
end

-- Initialize cache
function M.init()
  M.load_cache()

  -- Schedule periodic cache save
  vim.defer_fn(function()
    if cache_settings.enabled then
      M.save_cache()
      vim.defer_fn(M.init, 60000) -- Run every minute
    end
  end, 60000)
end

-- Setup cache with the API module
function M.setup(api)
  -- Replace specific API functions with cached versions

  -- Cache issue data
  api.get_issue_orig = api.get_issue
  api.get_issue = M.wrap('issues', function(issue_key)
    return issue_key
  end, api.get_issue_orig)

  -- Cache project data
  api.get_project_orig = api.get_project
  api.get_project = M.wrap('projects', function(project_key)
    return project_key
  end, api.get_project_orig)

  -- Cache user search
  api.find_users_orig = api.find_users
  api.find_users = M.wrap('users', function(query)
    return 'query:' .. query
  end, api.find_users_orig)

  -- Cache board data
  api.get_boards_orig = api.get_boards
  api.get_boards = M.wrap('boards', function()
    return 'all_boards'
  end, api.get_boards_orig)

  -- Cache project boards
  api.get_project_boards_orig = api.get_project_boards
  api.get_project_boards = M.wrap('boards', function(project_key)
    return 'project_boards:' .. project_key
  end, api.get_project_boards_orig)

  -- Cache sprints for a board
  api.get_sprints_orig = api.get_sprints
  api.get_sprints = M.wrap('sprints', function(board_id)
    return 'board_sprints:' .. board_id
  end, api.get_sprints_orig)

  -- Cache issue search results
  api.search_issues_orig = api.search_issues
  api.search_issues = M.wrap('search', function(jql, max_results)
    return 'jql:' .. jql .. '|' .. (max_results or 50)
  end, api.search_issues_orig)

  -- Initialize cache
  M.init()

  return true
end

return M
