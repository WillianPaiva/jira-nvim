local M = {}

local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

function M.is_jira_available()
  local handle = io.popen('which jira 2>/dev/null')
  local result = handle:read('*a')
  handle:close()
  return result and trim(result) ~= ''
end

function M.validate_issue_key(key)
  if not key or key == '' then
    return false, 'Issue key cannot be empty'
  end
  
  if not key:match('^[A-Z]+-[0-9]+$') then
    return false, 'Invalid issue key format. Expected format: PROJECT-123'
  end
  
  return true, nil
end

function M.parse_jira_output(output)
  if not output or output == '' then
    return {}
  end
  
  local lines = vim.split(output, '\n', { plain = true })
  local parsed = {}
  
  for _, line in ipairs(lines) do
    if line and trim(line) ~= '' then
      table.insert(parsed, line)
    end
  end
  
  return parsed
end

function M.sanitize_args(args)
  if not args then
    return ''
  end
  
  local sanitized = args:gsub('[;&|`$()]', '')
  return sanitized
end

function M.show_error(message)
  -- Use LazyVim's notification system if available
  local has_lazyvim, LazyVim = pcall(require, "lazyvim.util")
  if has_lazyvim and LazyVim.error then
    LazyVim.error(message, { title = "Jira" })
  else
    vim.notify('Jira Error: ' .. message, vim.log.levels.ERROR)
  end
end

function M.show_info(message, opts)
  opts = opts or {}
  -- If searching, don't show notifications
  if opts.searching then
    return
  end

  local has_lazyvim, LazyVim = pcall(require, "lazyvim.util")
  if has_lazyvim and LazyVim.info then
    LazyVim.info(message, { title = "Jira" })
  else
    vim.notify('Jira: ' .. message, vim.log.levels.INFO)
  end
end

function M.show_warning(message)
  local has_lazyvim, LazyVim = pcall(require, "lazyvim.util")
  if has_lazyvim and LazyVim.warn then
    LazyVim.warn(message, { title = "Jira" })
  else
    vim.notify('Jira Warning: ' .. message, vim.log.levels.WARN)
  end
end

return M