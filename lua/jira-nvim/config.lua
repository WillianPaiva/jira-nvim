local M = {}

local defaults = {
  -- API Connection Settings
  jira_url = nil,
  jira_email = nil,
  jira_api_token = nil,
  auth_type = 'basic',  -- 'basic' or 'bearer'
  project_key = nil,
  default_project = nil,
  default_board = nil,  -- Default board ID for sprints/epics
  
  -- Legacy CLI option (kept for backward compatibility, but not used)
  jira_cmd = nil,
  
  -- UI Settings
  use_floating_window = true,
  window_width = 0.8,
  window_height = 0.8,
  
  -- Visual enhancements
  show_icons = true,
  show_progress = true,
  enhanced_formatting = true,
  
  -- Custom colors for different issue types/statuses
  colors = {
    issue_key = 'Identifier',
    status = 'Statement',
    priority = 'Special',
    issue_type = 'Type',
    user = 'PreProc'
  },
  
  -- API options
  api_timeout = 10000,        -- 10 seconds timeout for API requests
  max_results = 50,           -- Maximum number of results to fetch in searches
  max_comments = 10,          -- Maximum number of comments to display
  
  -- Integration options
  enable_lsp_integration = false,  -- Enable LSP-based features (highlighting, hover, code actions)
  enable_git_integration = true,   -- Enable Git workflow features
  
  -- Caching options
  enable_caching = true,   -- Enable API response caching
  cache_ttl = 300,         -- Cache time-to-live in seconds (5 minutes)
  cache_size = 100,        -- Maximum number of items per cache type
  
  -- Error handling
  enhanced_error_handling = true,  -- Enable friendly error messages with troubleshooting tips
  
  -- Keymaps
  keymaps = {
    close = 'q',
    refresh = '<C-r>',
    open_browser = '<CR>',
    view_issue = 'v',
    transition_issue = 't',
    comment_issue = 'c',
    view_comments = 'C',
    assign_issue = 'a',
    watch_issue = 'w',
    toggle_bookmark = 'b',
    show_history = 'h',
    show_bookmarks = 'B',
    fuzzy_search = '/'
  }
}

M.options = {}

-- Check if configuration file exists
local function config_exists()
  local config_dir = vim.fn.stdpath('config') .. '/jira-nvim'
  local config_file = config_dir .. '/auth.json'
  return vim.fn.filereadable(config_file) == 1
end

-- Load credentials from config file
local function load_credentials()
  local config_dir = vim.fn.stdpath('config') .. '/jira-nvim'
  local config_file = config_dir .. '/auth.json'
  
  if vim.fn.filereadable(config_file) == 1 then
    local f = io.open(config_file, 'r')
    if f then
      local content = f:read('*all')
      f:close()
      
      local success, data = pcall(vim.fn.json_decode, content)
      if success and data then
        return data
      end
    end
  end
  
  return nil
end

-- Save credentials to config file
local function save_credentials(data)
  local config_dir = vim.fn.stdpath('config') .. '/jira-nvim'
  local config_file = config_dir .. '/auth.json'
  
  -- Create directory if it doesn't exist
  if vim.fn.isdirectory(config_dir) == 0 then
    vim.fn.mkdir(config_dir, 'p')
  end
  
  local f = io.open(config_file, 'w')
  if f then
    f:write(vim.fn.json_encode(data))
    f:close()
    -- Set file permissions to 600 (read/write by owner only)
    vim.fn.system('chmod 600 ' .. config_file)
    return true
  else
    return false
  end
end

function M.setup(opts)
  -- First, merge defaults with provided options
  M.options = vim.tbl_deep_extend('force', defaults, opts or {})
  
  -- Check if this is a forced interactive setup
  local force_setup = opts and opts.force_setup
  
  -- Try to load credentials from config file
  local creds = load_credentials()
  if creds and not force_setup then
    -- Only override if not explicitly provided in setup
    if not opts or not opts.jira_url then
      M.options.jira_url = creds.jira_url
    end
    if not opts or not opts.jira_email then
      M.options.jira_email = creds.jira_email
    end
    if not opts or not opts.jira_api_token then
      M.options.jira_api_token = creds.jira_api_token
    end
    if not opts or not opts.auth_type then
      M.options.auth_type = creds.auth_type or 'basic'
    end
    if not opts or not opts.project_key then
      M.options.project_key = creds.project_key
    end
    if not opts or not opts.default_board then
      M.options.default_board = creds.default_board
    end
  end
  
  -- Prompt for any missing required fields or if force_setup is true
  local needs_save = false
  
  if not M.options.jira_url or force_setup then
    M.options.jira_url = vim.fn.input({
      prompt = "Jira URL (e.g. https://your-domain.atlassian.net): ",
      default = M.options.jira_url or ""
    })
    needs_save = true
  end
  
  -- Ask for authentication type
  if not M.options.auth_type or force_setup then
    print("\nAuthentication Types:")
    print("1. Basic Auth (email + API token)")
    print("2. Bearer Token (for on-premise Jira servers)")
    
    local auth_choice = vim.fn.input({
      prompt = "Choose authentication type [1/2]: ",
      default = M.options.auth_type == "bearer" and "2" or "1"
    })
    
    if auth_choice == "2" then
      M.options.auth_type = "bearer"
    else
      M.options.auth_type = "basic"
    end
    needs_save = true
  end
  
  -- For Basic Auth, we need email
  if M.options.auth_type == "basic" and (not M.options.jira_email or force_setup) then
    M.options.jira_email = vim.fn.input({
      prompt = "Jira Email: ",
      default = M.options.jira_email or ""
    })
    needs_save = true
  end
  
  -- Both auth types need token
  if not M.options.jira_api_token or force_setup then
    if M.options.auth_type == "basic" then
      print("\nA Jira API token is required. Generate one at: https://id.atlassian.com/manage-profile/security/api-tokens")
    else
      print("\nEnter your Bearer token for Jira authentication")
    end
    
    local prompt = M.options.auth_type == "basic" and "Jira API Token: " or "Bearer Token: "
    M.options.jira_api_token = vim.fn.inputsecret({
      prompt = prompt,
      default = M.options.jira_api_token and "[keep existing token]" or ""
    })
    
    -- Keep existing token if user just pressed enter
    if M.options.jira_api_token == "[keep existing token]" and creds and creds.jira_api_token then
      M.options.jira_api_token = creds.jira_api_token
    else
      needs_save = true
    end
  end
  
  if not M.options.project_key or force_setup then
    M.options.project_key = vim.fn.input({
      prompt = "Default Jira project key (optional): ",
      default = M.options.project_key or ""
    })
    needs_save = true
  end
  
  -- Save credentials if they were just entered
  if needs_save then
    local save_creds = vim.fn.input("Save credentials for future sessions? (y/n): ")
    if save_creds:lower() == 'y' then
      save_credentials({
        jira_url = M.options.jira_url,
        jira_email = M.options.jira_email,
        jira_api_token = M.options.jira_api_token,
        auth_type = M.options.auth_type,
        project_key = M.options.project_key,
        default_board = M.options.default_board
      })
      print("\nCredentials saved!")
    end
  end
  
  -- Set default_project to project_key if not set
  if not M.options.default_project and M.options.project_key then
    M.options.default_project = M.options.project_key
  end
  
  -- Note: Default board will be handled after API setup to provide a list of boards
end

function M.get(key)
  return M.options[key]
end

-- Check if credentials are configured
function M.has_credentials()
  return M.options.jira_url and M.options.jira_url ~= '' and
         M.options.jira_email and M.options.jira_email ~= '' and
         M.options.jira_api_token and M.options.jira_api_token ~= ''
end

return M