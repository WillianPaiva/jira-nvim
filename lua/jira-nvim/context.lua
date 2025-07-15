local M = {}

local config = require('jira-nvim.config')
local api = require('jira-nvim.api')
local utils = require('jira-nvim.utils')

-- Cache for detected issue keys
M.issue_cache = {}

-- Get issue key pattern based on project key
function M.get_issue_pattern(project_key)
  if project_key then
    -- If project key is provided, make a specific pattern for that project
    return project_key .. "%-[0-9]+"
  else
    -- Generic pattern for any Jira issue key
    return "[A-Z][A-Z0-9]+%-[0-9]+"
  end
end

-- Detect issue key in text (like commit message or branch name)
function M.detect_issue_key(text)
  if not text or text == "" then
    return nil
  end
  
  local project_key = config.get('project_key')
  local pattern = M.get_issue_pattern(project_key)
  
  -- Return the first match
  return text:match(pattern)
end

-- Detect issue keys in current file
function M.detect_issue_keys_in_buffer(bufnr)
  bufnr = bufnr or 0
  
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local issue_keys = {}
  local project_key = config.get('project_key')
  local pattern = M.get_issue_pattern(project_key)
  
  for i, line in ipairs(lines) do
    for key in line:gmatch(pattern) do
      if not vim.tbl_contains(issue_keys, key) then
        table.insert(issue_keys, {
          key = key,
          line = i,
          text = line:gsub("^%s+", ""):sub(1, 50) -- Trim and limit length
        })
      end
    end
  end
  
  return issue_keys
end

-- Get current git branch
function M.get_current_branch()
  local branch = vim.fn.system("git branch --show-current 2>/dev/null")
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return branch:gsub("%s+$", "") -- Trim whitespace
end

-- Detect issue key from current git branch
function M.detect_issue_key_from_branch()
  local branch = M.get_current_branch()
  if not branch then
    return nil
  end
  
  return M.detect_issue_key(branch)
end

-- Get recent git commits
function M.get_recent_commits(count)
  count = count or 5
  local command = "git log -n " .. count .. " --pretty=format:'%s' 2>/dev/null"
  local output = vim.fn.system(command)
  
  if vim.v.shell_error ~= 0 then
    return {}
  end
  
  return vim.split(output, "\n")
end

-- Detect issue keys from recent commits
function M.detect_issue_keys_from_commits(count)
  local commits = M.get_recent_commits(count)
  local issue_keys = {}
  
  for _, commit in ipairs(commits) do
    local key = M.detect_issue_key(commit)
    if key and not vim.tbl_contains(issue_keys, key) then
      table.insert(issue_keys, key)
    end
  end
  
  return issue_keys
end

-- Get current working context
function M.get_current_context()
  local context = {
    branch_issue = M.detect_issue_key_from_branch(),
    commit_issues = M.detect_issue_keys_from_commits(5),
    buffer_issues = M.detect_issue_keys_in_buffer()
  }
  
  return context
end

-- Show context information in a window
function M.show_context()
  local context = M.get_current_context()
  local lines = {}
  
  table.insert(lines, "🔍 Jira Context Detection")
  table.insert(lines, "=======================")
  table.insert(lines, "")
  
  -- Show branch issue
  table.insert(lines, "📌 Current Branch:")
  if context.branch_issue then
    table.insert(lines, "  Found Issue Key: " .. context.branch_issue)
    
    -- Get issue details if not in cache
    if not M.issue_cache[context.branch_issue] then
      api.get_issue(context.branch_issue, function(err, issue)
        if not err and issue then
          M.issue_cache[context.branch_issue] = issue
          utils.show_info("Issue details loaded: " .. issue.fields.summary)
        end
      end)
    end
  else
    local branch = M.get_current_branch()
    if branch then
      table.insert(lines, "  Branch: " .. branch)
      table.insert(lines, "  No issue key detected in branch name")
    else
      table.insert(lines, "  Not in a git repository")
    end
  end
  
  -- Show commits
  table.insert(lines, "")
  table.insert(lines, "📝 Recent Commits:")
  if #context.commit_issues > 0 then
    table.insert(lines, "  Found Issue Keys:")
    for _, key in ipairs(context.commit_issues) do
      table.insert(lines, "  - " .. key)
    end
  else
    table.insert(lines, "  No issue keys detected in recent commits")
  end
  
  -- Show buffer issues
  table.insert(lines, "")
  table.insert(lines, "📄 Current File:")
  if #context.buffer_issues > 0 then
    table.insert(lines, "  Found Issue Keys:")
    for _, issue in ipairs(context.buffer_issues) do
      table.insert(lines, string.format("  - %s (line %d): %s", 
                                      issue.key, 
                                      issue.line,
                                      issue.text))
    end
  else
    table.insert(lines, "  No issue keys detected in current file")
  end
  
  -- Show actions
  table.insert(lines, "")
  table.insert(lines, "🚀 Available Actions:")
  if context.branch_issue then
    table.insert(lines, "  v - View branch issue details")
    table.insert(lines, "  o - Open branch issue in browser")
    table.insert(lines, "  t - Transition branch issue state")
    table.insert(lines, "  c - Comment on branch issue")
  end
  
  require('jira-nvim.ui').show_output("Jira Context", table.concat(lines, "\n"))
  
  -- Add custom keymaps for the context window
  local buf = vim.api.nvim_get_current_buf()
  
  -- View branch issue
  if context.branch_issue then
    vim.api.nvim_buf_set_keymap(buf, 'n', 'v', '', {
      noremap = true,
      silent = true,
      callback = function()
        require('jira-nvim.cli').issue_view(context.branch_issue)
      end,
      desc = 'View branch issue'
    })
    
    -- Open branch issue in browser
    vim.api.nvim_buf_set_keymap(buf, 'n', 'o', '', {
      noremap = true,
      silent = true,
      callback = function()
        require('jira-nvim.cli').open(context.branch_issue)
      end,
      desc = 'Open branch issue in browser'
    })
    
    -- Transition branch issue
    vim.api.nvim_buf_set_keymap(buf, 'n', 't', '', {
      noremap = true,
      silent = true,
      callback = function()
        -- Get available transitions
        require('jira-nvim.cli').get_available_transitions(context.branch_issue, function(err, states)
          if err then
            utils.show_error('Error fetching transitions: ' .. err)
            return
          end
          
          -- Show available states
          vim.ui.select(states, {
            prompt = 'Select new state for ' .. context.branch_issue .. ':',
          }, function(choice)
            if choice then
              require('jira-nvim.cli').issue_transition(context.branch_issue, choice)
            end
          end)
        end)
      end,
      desc = 'Transition branch issue'
    })
    
    -- Comment on branch issue
    vim.api.nvim_buf_set_keymap(buf, 'n', 'c', '', {
      noremap = true,
      silent = true,
      callback = function()
        require('jira-nvim.ui').show_comment_buffer(context.branch_issue)
      end,
      desc = 'Comment on branch issue'
    })
  end
end

-- Create commit with issue key (from branch or manually specified)
function M.create_commit_with_issue_key()
  local branch_issue = M.detect_issue_key_from_branch()
  
  local function create_commit(issue_key)
    if not issue_key or issue_key == "" then
      -- No issue key, just create regular commit
      vim.cmd('Git commit')
      return
    end
    
    -- Get issue details
    api.get_issue(issue_key, function(err, issue)
      if err then
        utils.show_error("Error fetching issue: " .. err .. "\nContinuing with commit...")
        vim.cmd('Git commit')
        return
      end
      
      -- Create commit message template with issue key and summary
      local summary = issue.fields.summary
      local commit_msg = issue_key .. ": "
      
      -- Open commit message with prefilled issue key
      vim.fn.inputsave()
      local msg = vim.fn.input({
        prompt = "Commit message: " .. commit_msg,
        default = summary
      })
      vim.fn.inputrestore()
      
      if msg ~= "" then
        local full_msg = commit_msg .. msg
        vim.fn.system('git commit -m "' .. full_msg .. '"')
        utils.show_info("Committed: " .. full_msg)
      else
        utils.show_warning("Commit aborted")
      end
    end)
  end
  
  if branch_issue then
    create_commit(branch_issue)
  else
    -- No issue in branch, ask for issue key
    vim.fn.inputsave()
    local issue_key = vim.fn.input({
      prompt = "Enter Jira issue key (leave empty to skip): "
    })
    vim.fn.inputrestore()
    
    create_commit(issue_key)
  end
end

-- Create a branch from issue key
function M.create_branch_from_issue()
  -- Get issue key
  vim.fn.inputsave()
  local issue_key = vim.fn.input({
    prompt = "Enter Jira issue key: "
  })
  vim.fn.inputrestore()
  
  if issue_key == "" then
    utils.show_warning("Branch creation aborted")
    return
  end
  
  -- Get issue details
  api.get_issue(issue_key, function(err, issue)
    if err then
      utils.show_error("Error fetching issue: " .. err)
      return
    end
    
    -- Create branch name from issue key and summary
    local summary = issue.fields.summary
    -- Sanitize summary for branch name:
    -- 1. Convert to lowercase
    -- 2. Replace spaces and special chars with dashes
    -- 3. Remove multiple consecutive dashes
    -- 4. Remove leading/trailing dashes
    local clean_summary = summary:lower()
      :gsub("[^%w%s-]", "")
      :gsub("%s+", "-")
      :gsub("%-+", "-")
      :gsub("^%-", "")
      :gsub("%-$", "")
      
    local branch_name = issue_key:lower() .. "-" .. clean_summary
    
    -- Allow user to edit branch name
    vim.fn.inputsave()
    local final_branch_name = vim.fn.input({
      prompt = "Branch name: ",
      default = branch_name
    })
    vim.fn.inputrestore()
    
    if final_branch_name ~= "" then
      -- Create the branch
      local result = vim.fn.system('git checkout -b "' .. final_branch_name .. '"')
      if vim.v.shell_error ~= 0 then
        utils.show_error("Failed to create branch: " .. result)
      else
        utils.show_info("Created branch: " .. final_branch_name)
      end
    else
      utils.show_warning("Branch creation aborted")
    end
  end)
end

-- Create a function to detect issue keys in current word under cursor
function M.get_issue_key_under_cursor()
  local word = vim.fn.expand("<cword>")
  
  -- Check if word matches issue key pattern
  local project_key = config.get('project_key')
  local pattern = M.get_issue_pattern(project_key)
  
  if word:match(pattern) then
    return word
  end
  
  return nil
end

-- Go to issue under cursor
function M.go_to_issue_under_cursor()
  local issue_key = M.get_issue_key_under_cursor()
  
  if issue_key then
    require('jira-nvim.cli').issue_view(issue_key)
  else
    utils.show_warning("No issue key found under cursor")
  end
end

-- Open issue under cursor in browser
function M.open_issue_under_cursor()
  local issue_key = M.get_issue_key_under_cursor()
  
  if issue_key then
    require('jira-nvim.cli').open(issue_key)
  else
    utils.show_warning("No issue key found under cursor")
  end
end

return M