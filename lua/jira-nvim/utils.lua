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

function M.show_error(message, title)
  title = title or "Jira Error"
  vim.notify(message, vim.log.levels.ERROR, { title = title })
end

function M.show_info(message, title)
  title = title or "Jira"
  vim.notify(message, vim.log.levels.INFO, { title = title })
end

function M.show_warning(message, title)
  title = title or "Jira Warning"
  vim.notify(message, vim.log.levels.WARN, { title = title })
end

function M.build_cmd_args(args_def)
  local args = {}
  for _, def in ipairs(args_def) do
    if def.value and def.value ~= "" and (not def.default or def.value ~= def.default) then
      if def.multi then
        for item in def.value:gmatch("[^,]+") do
          local trimmed_item = item:gsub("^%s*(.-)%s*$", "%1")
          if trimmed_item ~= "" then
            table.insert(args, string.format('%s "%s"', def.flag, trimmed_item))
          end
        end
      else
        local value = def.quote and def.value:gsub('"', '\\"') or def.value
        table.insert(args, string.format('%s "%s"', def.flag, value))
      end
    elseif not def.value and def.flag then
      table.insert(args, def.flag)
    end
  end
  return table.concat(args, ' ')
end

return M