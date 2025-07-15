local M = {}

local utils = require('jira-nvim.utils')
local config = require('jira-nvim.config')

-- Error categories
local ERROR_CATEGORIES = {
  AUTH = "authentication",
  PERMISSION = "permission",
  NOT_FOUND = "not_found",
  VALIDATION = "validation",
  SERVER = "server",
  NETWORK = "network",
  UNKNOWN = "unknown"
}

-- Common error patterns and their categories
local ERROR_PATTERNS = {
  -- Authentication errors
  { pattern = "401", category = ERROR_CATEGORIES.AUTH, message = "Authentication failed. Check your credentials." },
  { pattern = "[Aa]uthentication failed", category = ERROR_CATEGORIES.AUTH, message = "Authentication failed. Check your credentials." },
  { pattern = "API [Tt]oken", category = ERROR_CATEGORIES.AUTH, message = "API token is invalid or expired." },
  { pattern = "[Ii]nvalid [Cc]redentials", category = ERROR_CATEGORIES.AUTH, message = "Invalid credentials. Please check your Jira email and API token." },
  { pattern = "[Ll]ogin [Ff]ailed", category = ERROR_CATEGORIES.AUTH, message = "Login failed. Check your Jira email and API token." },

  -- Permission errors
  { pattern = "403", category = ERROR_CATEGORIES.PERMISSION, message = "Permission denied. You don't have access to this resource." },
  { pattern = "[Pp]ermission [Dd]enied", category = ERROR_CATEGORIES.PERMISSION, message = "Permission denied. You don't have access to this resource." },
  { pattern = "[Nn]ot [Aa]uthorized", category = ERROR_CATEGORIES.PERMISSION, message = "Not authorized. You don't have permission to perform this action." },

  -- Not Found errors
  { pattern = "404", category = ERROR_CATEGORIES.NOT_FOUND, message = "Resource not found. Check that the issue or project exists." },
  { pattern = "[Nn]ot [Ff]ound", category = ERROR_CATEGORIES.NOT_FOUND, message = "Resource not found. Check that the issue or project exists." },
  { pattern = "does not exist", category = ERROR_CATEGORIES.NOT_FOUND, message = "The requested resource does not exist." },

  -- Validation errors
  { pattern = "400", category = ERROR_CATEGORIES.VALIDATION, message = "Invalid request. Check your input parameters." },
  { pattern = "[Ii]nvalid", category = ERROR_CATEGORIES.VALIDATION, message = "Invalid input. Please check your parameters." },
  { pattern = "[Rr]equired field", category = ERROR_CATEGORIES.VALIDATION, message = "Missing required field. Check your input." },
  { pattern = "Field is required", category = ERROR_CATEGORIES.VALIDATION, message = "Missing required field. Check your input." },

  -- Server errors
  { pattern = "5%d%d", category = ERROR_CATEGORIES.SERVER, message = "Jira server error. Please try again later." },
  { pattern = "[Ss]erver [Ee]rror", category = ERROR_CATEGORIES.SERVER, message = "Jira server error. Please try again later." },
  { pattern = "[Ii]nternal [Ee]rror", category = ERROR_CATEGORIES.SERVER, message = "Jira internal error. Please try again later." },

  -- Network errors
  { pattern = "[Nn]etwork", category = ERROR_CATEGORIES.NETWORK, message = "Network error. Check your connection." },
  { pattern = "[Tt]imeout", category = ERROR_CATEGORIES.NETWORK, message = "Request timed out. Check your connection or try again later." },
  { pattern = "[Cc]onnection [Rr]efused", category = ERROR_CATEGORIES.NETWORK, message = "Connection refused. Check your Jira URL or network settings." }
}

-- Solution hints by category
local SOLUTION_HINTS = {
  [ERROR_CATEGORIES.AUTH] = {
    "Run :JiraSetup to reconfigure your credentials.",
    "Check that your API token is valid and not expired at https://id.atlassian.com/manage-profile/security/api-tokens.",
    "Ensure your email matches the one registered with Atlassian.",
    "Make sure your Jira URL is correct (should be like https://your-domain.atlassian.net)."
  },
  
  [ERROR_CATEGORIES.PERMISSION] = {
    "Contact your Jira administrator to request access.",
    "Check if you have the necessary project role or permissions.",
    "Verify that your account has access to this project or issue.",
    "Some Jira actions require specific permissions that you might not have."
  },
  
  [ERROR_CATEGORIES.NOT_FOUND] = {
    "Check that you're using the correct issue key or project key.",
    "Verify that the issue or project exists in your Jira instance.",
    "The issue might have been deleted or moved.",
    "If you're using a board ID, verify that it exists with :JiraShowBoards."
  },
  
  [ERROR_CATEGORIES.VALIDATION] = {
    "Check your input parameters for errors.",
    "Ensure required fields are provided and have valid values.",
    "Some fields might have constraints (e.g., character limits, format).",
    "Jira projects may have custom required fields for issue creation."
  },
  
  [ERROR_CATEGORIES.SERVER] = {
    "Try again later as the Jira server might be experiencing issues.",
    "Check the Jira status page for any ongoing incidents.",
    "This is often a temporary issue that resolves itself.",
    "If the problem persists, contact your Jira administrator."
  },
  
  [ERROR_CATEGORIES.NETWORK] = {
    "Check your internet connection.",
    "Ensure the Jira URL is accessible from your network.",
    "There might be firewall or proxy settings blocking the connection.",
    "Try increasing the API timeout setting in your configuration.",
    "If you're behind a corporate firewall, you may need to configure proxy settings."
  },
  
  [ERROR_CATEGORIES.UNKNOWN] = {
    "Try running :JiraSetup to reconfigure the plugin.",
    "Check your Jira URL and credentials.",
    "Restart Neovim and try again.",
    "Check the error message for specific details that might help resolve the issue."
  }
}

-- Function to categorize an error message
function M.categorize_error(error_message)
  if not error_message then
    return ERROR_CATEGORIES.UNKNOWN
  end
  
  for _, pattern in ipairs(ERROR_PATTERNS) do
    if error_message:match(pattern.pattern) then
      return pattern.category, pattern.message
    end
  end
  
  return ERROR_CATEGORIES.UNKNOWN
end

-- Function to get solution hints for a category
function M.get_solution_hints(category)
  return SOLUTION_HINTS[category] or SOLUTION_HINTS[ERROR_CATEGORIES.UNKNOWN]
end

-- Function to format a friendly error message
function M.format_friendly_error(error_message)
  local category, friendly_message = M.categorize_error(error_message)
  local hints = M.get_solution_hints(category)
  
  -- Select 2 random hints
  local selected_hints = {}
  if hints and #hints > 0 then
    -- Seed random number generator
    math.randomseed(os.time())
    
    -- Get two unique random hints if possible
    local indices = {}
    for i = 1, #hints do
      table.insert(indices, i)
    end
    
    -- Fisher-Yates shuffle
    for i = #indices, 2, -1 do
      local j = math.random(i)
      indices[i], indices[j] = indices[j], indices[i]
    end
    
    -- Take first 2 (or fewer if not enough)
    local max_hints = math.min(2, #hints)
    for i = 1, max_hints do
      table.insert(selected_hints, hints[indices[i]])
    end
  end
  
  -- Format the message
  local result = {
    "❌ " .. (friendly_message or "An error occurred"),
    "",
    "Details: " .. error_message,
    "",
    "Possible solutions:"
  }
  
  for _, hint in ipairs(selected_hints) do
    table.insert(result, "• " .. hint)
  end
  
  return table.concat(result, "\n")
end

-- Function to handle API errors
function M.handle_api_error(error_message, retry_fn)
  -- Format a friendly error message
  local friendly_message = M.format_friendly_error(error_message)
  
  -- Show the error with retry button if a retry function is provided
  if retry_fn and type(retry_fn) == "function" then
    -- Function to show the message with a retry option
    local function show_with_retry()
      if vim.fn.has('nvim-0.6') == 1 then
        -- Use vim.notify with action buttons for newer Neovim
        vim.notify(friendly_message, vim.log.levels.ERROR, {
          title = "Jira Error",
          on_open = function(win)
            local buf = vim.api.nvim_win_get_buf(win)
            vim.api.nvim_buf_set_keymap(buf, 'n', 'r', '', {
              callback = function()
                vim.api.nvim_win_close(win, true)
                retry_fn()
              end,
              noremap = true,
              silent = true,
              desc = 'Retry'
            })
            vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '', {
              callback = function()
                vim.api.nvim_win_close(win, true)
              end,
              noremap = true,
              silent = true,
              desc = 'Close'
            })
            vim.api.nvim_echo({{"\nPress 'r' to retry or 'q' to close", "WarningMsg"}}, false, {})
          end
        })
      else
        -- Fallback for older Neovim versions
        utils.show_error(friendly_message .. "\n\nType :JiraRetry to retry the operation.")
        
        -- Register a command to retry
        vim.api.nvim_create_user_command('JiraRetry', retry_fn, {
          desc = 'Retry the last failed Jira operation'
        })
      end
    end
    
    show_with_retry()
  else
    -- Just show the error message
    utils.show_error(friendly_message)
  end
end

-- Wrap an API function with error handling
function M.wrap_with_error_handling(fn)
  return function(...)
    local args = {...}
    local callback = args[#args]
    
    if type(callback) ~= 'function' then
      -- If no callback, just call the original function
      return fn(...)
    end
    
    -- Replace the callback with our error-handling version
    args[#args] = function(err, data)
      if err then
        -- Prepare a retry function
        local retry_fn = function()
          -- Call the original function again with the same arguments
          fn(unpack(args))
        end
        
        -- Handle the error
        M.handle_api_error(err, retry_fn)
      end
      
      -- Always call the original callback
      callback(err, data)
    end
    
    -- Call the original function with modified callback
    return fn(unpack(args))
  end
end

-- Setup error handling
function M.setup(api)
  -- Only wrap functions if enhanced error handling is enabled
  if not config.get('enhanced_error_handling') then
    return
  end
  
  -- Wrap API functions with error handling
  for name, func in pairs(api) do
    -- Only wrap functions that might be API calls
    if type(func) == 'function' and name:match('^get_') or name:match('^search_') then
      api[name] = M.wrap_with_error_handling(func)
    end
  end
  
  return true
end

-- Show common troubleshooting tips
function M.show_troubleshooting()
  local tips = {
    "🔧 Jira Troubleshooting Guide",
    "===========================",
    "",
    "Common Issues and Solutions:",
    "",
    "1️⃣ Authentication Problems:",
    "• Run :JiraSetup to reconfigure your credentials",
    "• Verify your API token at: https://id.atlassian.com/manage-profile/security/api-tokens",
    "• Check that your email matches your Atlassian account",
    "• Ensure your Jira URL is correct (https://your-domain.atlassian.net)",
    "• Test connection with :JiraTestConnection",
    "",
    "2️⃣ Issue Not Found or Permission Errors:",
    "• Verify you have access to the issue or project",
    "• Check that you're using the correct issue key",
    "• You might need additional permissions for certain operations",
    "• Run :JiraStatus to check your configuration",
    "",
    "3️⃣ Network or Connectivity Issues:",
    "• Check your internet connection",
    "• Verify the Jira URL is accessible from your network",
    "• Try increasing the API timeout in your configuration",
    "• If using a proxy, ensure it's configured correctly",
    "",
    "4️⃣ Configuration Issues:",
    "• Your configuration is stored in: " .. vim.fn.stdpath('config') .. "/jira-nvim/",
    "• Check for any typos in your project or board IDs",
    "• Run :JiraStatus to view your current configuration",
    "",
    "5️⃣ Common Commands for Debugging:",
    "• :JiraTestConnection - Test API connection",
    "• :JiraStatus - View configuration status",
    "• :JiraCacheStats - View cache statistics",
    "• :JiraCacheClear - Clear all caches",
    "",
    "6️⃣ Getting Help:",
    "• Check the plugin documentation: https://github.com/WillianPaiva/jira-nvim-plugin",
    "• Run :JiraHelp to view all available commands",
    "• Submit issues on GitHub for bugs or feature requests",
    "",
    "If you continue experiencing problems, try restarting Neovim or",
    "completely reconfiguring the plugin with :JiraSetup."
  }
  
  require('jira-nvim.ui').show_output("Jira Troubleshooting", table.concat(tips, "\n"))
end

return M