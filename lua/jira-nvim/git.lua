local M = {}

local api = require('jira-nvim.api')
local config = require('jira-nvim.config')
local utils = require('jira-nvim.utils')
local context = require('jira-nvim.context')

-- Check if git is available
function M.is_git_available()
  local result = vim.fn.system('git --version')
  return vim.v.shell_error == 0
end

-- Get the root directory of the git repository
function M.get_git_root()
  local result = vim.fn.system('git rev-parse --show-toplevel 2>/dev/null')
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return result:gsub('%s+$', '') -- Trim whitespace
end

-- Get the current git branch
function M.get_current_branch()
  local branch = vim.fn.system("git branch --show-current 2>/dev/null")
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return branch:gsub("%s+$", "") -- Trim whitespace
end

-- Get recent git commits
function M.get_recent_commits(count)
  count = count or 10
  local command = "git log -n " .. count .. " --pretty=format:'%h|%s|%an|%ad' --date=short 2>/dev/null"
  local output = vim.fn.system(command)
  
  if vim.v.shell_error ~= 0 then
    return {}
  end
  
  local commits = {}
  for line in output:gmatch("[^\n]+") do
    local hash, subject, author, date = line:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)")
    if hash and subject then
      table.insert(commits, {
        hash = hash,
        subject = subject,
        author = author,
        date = date,
        issue_key = context.detect_issue_key(subject)
      })
    end
  end
  
  return commits
end

-- Create a branch for a Jira issue
function M.create_branch_for_issue(issue_key, branch_prefix)
  if not M.is_git_available() then
    utils.show_error("Git is not available")
    return
  end
  
  -- Check if we're in a git repository
  if not M.get_git_root() then
    utils.show_error("Not in a git repository")
    return
  end
  
  -- Get issue details
  api.get_issue(issue_key, function(err, issue)
    if err then
      utils.show_error("Failed to fetch issue: " .. err)
      return
    end
    
    -- Create branch name from issue key and summary
    local summary = issue.fields.summary
    -- Clean up the summary for a branch name:
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
    
    -- Apply prefix if provided
    local prefix = ""
    if branch_prefix and branch_prefix ~= "" then
      prefix = branch_prefix .. "/"
    end
    
    -- Default branch name
    local branch_name = prefix .. issue_key:lower() .. "-" .. clean_summary
    
    -- Let user edit the branch name
    vim.fn.inputsave()
    local final_name = vim.fn.input({
      prompt = "Branch name: ",
      default = branch_name
    })
    vim.fn.inputrestore()
    
    if final_name == "" then
      utils.show_warning("Branch creation canceled")
      return
    end
    
    -- Create the branch
    local result = vim.fn.system('git checkout -b "' .. final_name .. '"')
    if vim.v.shell_error ~= 0 then
      utils.show_error("Failed to create branch: " .. result)
    else
      utils.show_info("Created branch: " .. final_name)
    end
  end)
end

-- Link a commit to a Jira issue
function M.link_commit_to_issue(commit_hash, issue_key)
  -- Check if we're in a git repository
  if not M.is_git_available() or not M.get_git_root() then
    utils.show_error("Not in a git repository")
    return
  end
  
  -- Verify the commit hash exists
  local commit_check = vim.fn.system('git rev-parse --verify ' .. commit_hash .. ' 2>/dev/null')
  if vim.v.shell_error ~= 0 then
    utils.show_error("Invalid commit hash: " .. commit_hash)
    return
  end
  
  -- Get the commit message
  local commit_msg = vim.fn.system('git log -n 1 --pretty=format:%s ' .. commit_hash)
  if vim.v.shell_error ~= 0 then
    utils.show_error("Failed to get commit message")
    return
  end
  
  -- Check if the commit already references the issue
  if commit_msg:match(issue_key) then
    utils.show_info("Commit already references issue " .. issue_key)
    return
  end
  
  -- Create a new commit message with the issue key
  local new_msg = issue_key .. ": " .. commit_msg
  
  -- Amend the commit with the new message
  local result = vim.fn.system('git commit --amend -m "' .. new_msg .. '"')
  if vim.v.shell_error ~= 0 then
    utils.show_error("Failed to amend commit: " .. result)
    return
  end
  
  utils.show_info("Linked commit " .. commit_hash:sub(1, 7) .. " to issue " .. issue_key)
end

-- Show commit history with Jira issue links
function M.show_commit_history()
  -- Check if we're in a git repository
  if not M.is_git_available() or not M.get_git_root() then
    utils.show_error("Not in a git repository")
    return
  end
  
  local commits = M.get_recent_commits(20)
  local lines = {}
  
  table.insert(lines, "📝 Git Commit History with Jira Links")
  table.insert(lines, "===================================")
  table.insert(lines, "")
  
  for i, commit in ipairs(commits) do
    local issue_info = ""
    if commit.issue_key then
      issue_info = " [" .. commit.issue_key .. "]"
    end
    
    table.insert(lines, string.format("%s %s%s", 
      commit.hash:sub(1, 7),
      commit.date,
      issue_info
    ))
    table.insert(lines, "   " .. commit.subject)
    table.insert(lines, "   " .. commit.author)
    table.insert(lines, "")
  end
  
  -- Add footer with actions
  table.insert(lines, "")
  table.insert(lines, "Actions:")
  table.insert(lines, "  l - Link commit to Jira issue")
  table.insert(lines, "  v - View Jira issue for commit")
  table.insert(lines, "  o - Open Jira issue in browser")
  
  -- Show the output
  local buf, win = require('jira-nvim.ui').show_output("Git Commits", table.concat(lines, "\n"))
  
  -- Add keymaps for the buffer
  vim.api.nvim_buf_set_keymap(buf, 'n', 'l', '', {
    noremap = true,
    silent = true,
    callback = function()
      local line = vim.api.nvim_get_current_line()
      local commit_hash = line:match("^([a-f0-9]+)") -- Match the commit hash at the start of the line
      
      if commit_hash then
        -- Ask for issue key to link
        vim.fn.inputsave()
        local issue_key = vim.fn.input({
          prompt = "Enter Jira issue key to link: "
        })
        vim.fn.inputrestore()
        
        if issue_key ~= "" then
          M.link_commit_to_issue(commit_hash, issue_key)
        end
      else
        utils.show_warning("No commit hash found on current line")
      end
    end,
    desc = 'Link commit to Jira issue'
  })
  
  -- View Jira issue for commit
  vim.api.nvim_buf_set_keymap(buf, 'n', 'v', '', {
    noremap = true,
    silent = true,
    callback = function()
      local line = vim.api.nvim_get_current_line()
      local issue_key = line:match("%[([A-Z]+-[0-9]+)%]")
      
      if issue_key then
        require('jira-nvim.cli').issue_view(issue_key)
      else
        utils.show_warning("No Jira issue found on current line")
      end
    end,
    desc = 'View Jira issue for commit'
  })
  
  -- Open Jira issue in browser
  vim.api.nvim_buf_set_keymap(buf, 'n', 'o', '', {
    noremap = true,
    silent = true,
    callback = function()
      local line = vim.api.nvim_get_current_line()
      local issue_key = line:match("%[([A-Z]+-[0-9]+)%]")
      
      if issue_key then
        require('jira-nvim.cli').open(issue_key)
      else
        utils.show_warning("No Jira issue found on current line")
      end
    end,
    desc = 'Open Jira issue in browser'
  })
end

-- Create a branch prefix selector
function M.branch_prefix_selector(callback)
  local common_prefixes = {
    "feature",
    "bugfix",
    "hotfix",
    "release",
    "support",
    "chore",
    "docs",
    "test",
    "refactor"
  }
  
  vim.ui.select(common_prefixes, {
    prompt = "Select branch prefix:",
  }, function(choice)
    if callback then
      callback(choice)
    end
  end)
end

-- Create a branch with common prefix selector
function M.create_branch_with_prefix()
  -- Ask for issue key
  vim.fn.inputsave()
  local issue_key = vim.fn.input({
    prompt = "Enter Jira issue key: "
  })
  vim.fn.inputrestore()
  
  if issue_key == "" then
    utils.show_warning("Branch creation canceled")
    return
  end
  
  -- Show prefix selector
  M.branch_prefix_selector(function(prefix)
    M.create_branch_for_issue(issue_key, prefix)
  end)
end

-- Update Jira issue with git branch info
function M.update_issue_with_branch()
  local branch = M.get_current_branch()
  if not branch then
    utils.show_error("Not in a git repository")
    return
  end
  
  local issue_key = context.detect_issue_key(branch)
  if not issue_key then
    utils.show_warning("No issue key found in branch name: " .. branch)
    return
  end
  
  -- Add comment to issue with branch info
  local repo_root = M.get_git_root()
  local repo_name = repo_root:match("([^/]+)$") -- Get the last part of the path
  
  local comment = string.format("Branch created: `%s` in repository `%s`", branch, repo_name)
  api.add_comment(issue_key, comment, function(err, _)
    if err then
      utils.show_error("Failed to update issue: " .. err)
    else
      utils.show_info("Updated issue " .. issue_key .. " with branch info")
    end
  end)
end

-- Show workflow hooks commands
function M.show_git_hooks_help()
  local lines = {
    "🪝 Jira Git Workflow Hooks",
    "=======================",
    "",
    "To automatically link Jira with Git, add these hooks to your Git workflow:",
    "",
    "1. Post-commit hook (adds Jira issue key to commit if not present)",
    "```bash",
    "#!/bin/bash",
    "# Add this file to .git/hooks/post-commit and make executable (chmod +x)",
    "",
    "# Get the current branch name",
    "branch=$(git branch --show-current)",
    "",
    "# Extract Jira issue key (format: PROJECT-123)",
    "issue=$(echo \"$branch\" | grep -o -E '[A-Z]+-[0-9]+')",
    "",
    "# If we found an issue key and the commit doesn't already reference it",
    "if [ ! -z \"$issue\" ]; then",
    "  commit_msg=$(git log -1 --pretty=%B)",
    "  if ! echo \"$commit_msg\" | grep -q \"$issue\"; then",
    "    # Amend the commit to include the Jira issue key",
    "    git commit --amend -m \"$issue: $commit_msg\" --no-edit",
    "    echo \"Commit message updated with Jira issue key: $issue\"",
    "  fi",
    "fi",
    "```",
    "",
    "2. Post-checkout hook (to update Jira with branch info)",
    "```bash",
    "#!/bin/bash",
    "# Add this file to .git/hooks/post-checkout and make executable (chmod +x)",
    "",
    "# Skip if not a branch checkout",
    "[ \"$3\" -ne 1 ] && exit 0",
    "",
    "# Get the new branch name",
    "branch=$(git branch --show-current)",
    "",
    "# Extract Jira issue key",
    "issue=$(echo \"$branch\" | grep -o -E '[A-Z]+-[0-9]+')",
    "",
    "# If we found an issue key, update Jira (requires jira-cli)",
    "if [ ! -z \"$issue\" ] && command -v jira &> /dev/null; then",
    "  jira issue comment add \"$issue\" \"Branch created: \\`$branch\\`\"",
    "fi",
    "```",
    "",
    "3. Install hooks with JiraInstallGitHooks command",
    "",
    "Run :JiraInstallGitHooks to automatically install these hooks in your repository"
  }
  
  require('jira-nvim.ui').show_output("Git Workflow Hooks", table.concat(lines, "\n"))
end

-- Install git hooks for Jira workflow
function M.install_git_hooks()
  -- Check if we're in a git repository
  local repo_root = M.get_git_root()
  if not repo_root then
    utils.show_error("Not in a git repository")
    return
  end
  
  -- Create hooks directory if it doesn't exist
  local hooks_dir = repo_root .. "/.git/hooks"
  vim.fn.system('mkdir -p ' .. hooks_dir)
  
  -- Post-commit hook
  local post_commit_hook = [[
#!/bin/bash
# Auto-generated by jira-nvim

# Get the current branch name
branch=$(git branch --show-current)

# Extract Jira issue key (format: PROJECT-123)
issue=$(echo "$branch" | grep -o -E '[A-Z]+-[0-9]+')

# If we found an issue key and the commit doesn't already reference it
if [ ! -z "$issue" ]; then
  commit_msg=$(git log -1 --pretty=%B)
  if ! echo "$commit_msg" | grep -q "$issue"; then
    # Amend the commit to include the Jira issue key
    git commit --amend -m "$issue: $commit_msg" --no-verify
    echo "Commit message updated with Jira issue key: $issue"
  fi
fi
]]

  -- Post-checkout hook
  local post_checkout_hook = [[
#!/bin/bash
# Auto-generated by jira-nvim

# Skip if not a branch checkout
[ "$3" -ne 1 ] && exit 0

# Get the new branch name
branch=$(git branch --show-current)

# Extract Jira issue key
issue=$(echo "$branch" | grep -o -E '[A-Z]+-[0-9]+')

# If we found an issue key and nvim is available, update Jira using jira-nvim
if [ ! -z "$issue" ] && command -v nvim &> /dev/null; then
  nvim --headless -c "lua require('jira-nvim.api').add_comment('$issue', 'Branch created: `$branch`', function() vim.cmd('qa!') end)" -c "lua vim.defer_fn(function() vim.cmd('qa!') end, 5000)"
fi
]]

  -- Write the hooks
  local post_commit_path = hooks_dir .. "/post-commit"
  local f = io.open(post_commit_path, 'w')
  if f then
    f:write(post_commit_hook)
    f:close()
    vim.fn.system('chmod +x ' .. post_commit_path)
  else
    utils.show_error("Failed to create post-commit hook")
  end
  
  local post_checkout_path = hooks_dir .. "/post-checkout"
  local f = io.open(post_checkout_path, 'w')
  if f then
    f:write(post_checkout_hook)
    f:close()
    vim.fn.system('chmod +x ' .. post_checkout_path)
  else
    utils.show_error("Failed to create post-checkout hook")
  end
  
  utils.show_info("Git hooks installed in " .. hooks_dir)
end

return M