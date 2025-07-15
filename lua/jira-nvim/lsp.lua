local M = {}

local api = require('jira-nvim.api')
local config = require('jira-nvim.config')
local utils = require('jira-nvim.utils')
local context = require('jira-nvim.context')

-- Issue cache for hover info
M.issue_cache = {}

-- Check if LSP is available
function M.is_lsp_available()
  return vim.fn.has('nvim-0.7') == 1
end

-- Check if Treesitter is available
function M.is_treesitter_available()
  return pcall(require, 'nvim-treesitter')
end

-- Format issue info for hover
function M.format_issue_hover_info(issue)
  if not issue or not issue.fields then
    return "Issue not found or access denied"
  end
  
  local lines = {}
  
  -- Title
  table.insert(lines, "# " .. issue.key .. ": " .. issue.fields.summary)
  table.insert(lines, "")
  
  -- Status and priority
  table.insert(lines, "**Status:** " .. issue.fields.status.name)
  table.insert(lines, "**Priority:** " .. issue.fields.priority.name)
  
  -- Assignee
  if issue.fields.assignee and type(issue.fields.assignee) == 'table' and issue.fields.assignee.displayName then
    table.insert(lines, "**Assignee:** " .. issue.fields.assignee.displayName)
  else
    table.insert(lines, "**Assignee:** Unassigned")
  end
  
  -- Description (truncated)
  local description = ""
  if issue.renderedFields and issue.renderedFields.description then
    description = issue.renderedFields.description
  elseif issue.fields.description then
    if type(issue.fields.description) == 'table' and issue.fields.description.content then
      for _, content in ipairs(issue.fields.description.content) do
        if content.content then
          for _, text_item in ipairs(content.content) do
            if text_item.text then
              description = description .. text_item.text .. " "
            end
          end
        end
      end
    elseif type(issue.fields.description) == 'string' then
      description = issue.fields.description
    end
  end
  
  -- Truncate description to a reasonable length
  if description and description ~= "" then
    description = description:sub(1, 200)
    if #description == 200 then
      description = description .. "..."
    end
    table.insert(lines, "")
    table.insert(lines, "**Description:**")
    table.insert(lines, description)
  end
  
  -- Actions
  table.insert(lines, "")
  table.insert(lines, "_Actions:_ [View](" .. api.get_browse_url(issue.key) .. ") | Run `:JiraIssueView " .. issue.key .. "`")
  
  return table.concat(lines, "\n")
end

-- Register hover handler for issue keys
function M.setup_hover_handler()
  if not M.is_lsp_available() then
    utils.show_warning("Neovim 0.7+ required for LSP integration")
    return
  end
  
  -- Create a namespace for virtual text
  M.namespace = vim.api.nvim_create_namespace('jira-nvim')
  
  -- Create autocommands for issue key highlighting
  vim.api.nvim_create_autocmd({"BufEnter", "BufWritePost"}, {
    callback = function(args)
      M.highlight_issue_keys(args.buf)
    end,
    desc = "Highlight Jira issue keys in buffer"
  })
  
  -- Register hover handler
  vim.lsp.handlers["textDocument/hover"] = function(err, result, ctx, config)
    if err or not result or not result.contents then
      return vim.lsp.handlers.hover(err, result, ctx, config)
    end
    
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    
    -- Extract the word under cursor
    local word_start = line:sub(1, col):match(".*()%S+$") or col
    local word_end = line:sub(col + 1):match("^%S+()") or (col + 1)
    if not word_start then
      word_start = col
    end
    if not word_end then
      word_end = col + 1
    else
      word_end = word_end + col
    end
    
    local word = line:sub(word_start, word_end)
    
    -- Check if it looks like a Jira issue key
    local project_key = config.get('project_key')
    local pattern = project_key and project_key .. "%-[0-9]+" or "[A-Z][A-Z0-9]+%-[0-9]+"
    
    if word:match(pattern) then
      local issue_key = word:match(pattern)
      
      -- Add hover info for the Jira issue
      if M.issue_cache[issue_key] then
        -- Use cached issue info
        local hover_text = M.format_issue_hover_info(M.issue_cache[issue_key])
        
        -- Override hover with issue info
        result.contents = {
          kind = "markdown",
          value = hover_text
        }
      else
        -- Fetch issue info
        api.get_issue(issue_key, function(err, issue)
          if not err and issue then
            M.issue_cache[issue_key] = issue
            
            -- Since this is async, we can't modify the current hover
            -- But we can show a notification
            utils.show_info(issue.key .. ": " .. issue.fields.summary)
          end
        end)
        
        -- In the meantime, show a loading message
        result.contents = {
          kind = "markdown",
          value = "# " .. issue_key .. "\n\nLoading issue details..."
        }
      end
    end
    
    -- Call the original handler with potentially modified results
    return vim.lsp.handlers.hover(err, result, ctx, config)
  end
  
  utils.show_info("Jira LSP hover handler registered")
end

-- Highlight Jira issue keys in buffer
function M.highlight_issue_keys(bufnr)
  bufnr = bufnr or 0
  
  -- Clear previous highlights
  vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)
  
  -- Find issue keys in buffer
  local issue_keys = context.detect_issue_keys_in_buffer(bufnr)
  
  -- Set virtual text for each issue key
  for _, issue in ipairs(issue_keys) do
    -- If the issue is in cache, show status and assignee
    if M.issue_cache[issue.key] then
      local cached = M.issue_cache[issue.key]
      local status = cached.fields.status.name
      local assignee = "Unassigned"
      if cached.fields.assignee and type(cached.fields.assignee) == 'table' and cached.fields.assignee.displayName then
        assignee = cached.fields.assignee.displayName
      end
      
      vim.api.nvim_buf_set_virtual_text(
        bufnr,
        M.namespace,
        issue.line - 1,  -- 0-indexed
        {
          {" 📌 " .. status .. " (Assignee: " .. assignee .. ")", "Comment"}
        },
        {}
      )
    else
      -- Fetch issue info if not in cache
      api.get_issue(issue.key, function(err, issue_data)
        if not err and issue_data then
          M.issue_cache[issue.key] = issue_data
          
          -- Add virtual text with status and assignee
          local status = issue_data.fields.status.name
          local assignee = "Unassigned"
          if issue_data.fields.assignee and type(issue_data.fields.assignee) == 'table' and issue_data.fields.assignee.displayName then
            assignee = issue_data.fields.assignee.displayName
          end
          
          -- Make sure the buffer still exists
          if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_set_virtual_text(
              bufnr,
              M.namespace,
              issue.line - 1,  -- 0-indexed
              {
                {" 📌 " .. status .. " (Assignee: " .. assignee .. ")", "Comment"}
              },
              {}
            )
          end
        end
      end)
    end
  end
end

-- Register Jira issue key highlighting
function M.setup_highlighting()
  if vim.fn.has('nvim-0.7') == 0 then
    return
  end
  
  -- Create autocmd for initial highlighting
  vim.api.nvim_create_autocmd("FileType", {
    pattern = {"*"},
    callback = function(args)
      M.highlight_issue_keys(args.buf)
    end,
    desc = "Highlight Jira issue keys on file load"
  })
  
  -- Create autocmd for cursor hover
  vim.api.nvim_create_autocmd("CursorHold", {
    pattern = {"*"},
    callback = function()
      local line = vim.api.nvim_get_current_line()
      local col = vim.api.nvim_win_get_cursor(0)[2]
      
      -- Extract the word under cursor
      local word_start = line:sub(1, col):match(".*()%S+$") or col
      local word_end = line:sub(col + 1):match("^%S+()") or (col + 1)
      if not word_start then
        word_start = col
      end
      if not word_end then
        word_end = col + 1
      else
        word_end = word_end + col
      end
      
      local word = line:sub(word_start, word_end)
      
      -- Check if it looks like a Jira issue key
      local project_key = config.get('project_key')
      local pattern = project_key and project_key .. "%-[0-9]+" or "[A-Z][A-Z0-9]+%-[0-9]+"
      
      if word:match(pattern) then
        local issue_key = word:match(pattern)
        
        -- Check if we need to fetch the issue
        if not M.issue_cache[issue_key] then
          api.get_issue(issue_key, function(err, issue)
            if not err and issue then
              M.issue_cache[issue_key] = issue
              
              -- Refresh highlighting
              M.highlight_issue_keys(0)
            end
          end)
        end
      end
    end,
    desc = "Fetch Jira issue details on hover"
  })
  
  utils.show_info("Jira issue key highlighting enabled")
end

-- Create code actions for Jira issue keys
function M.setup_code_actions()
  if not M.is_lsp_available() then
    utils.show_warning("Neovim 0.7+ required for LSP integration")
    return
  end
  
  -- Register code actions provider
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client then return end
      
      if client.server_capabilities.codeActionProvider then
        -- Create the handler
        client.server_capabilities.codeActionProvider = {
          resolveProvider = true,
          codeActionKinds = { "quickfix", "refactor" }
        }
        
        -- Override the code action handler
        local old_handler = vim.lsp.handlers["textDocument/codeAction"]
        vim.lsp.handlers["textDocument/codeAction"] = function(err, result, ctx, config)
          -- Get the word under cursor
          local line = vim.api.nvim_get_current_line()
          local col = vim.api.nvim_win_get_cursor(0)[2]
          
          -- Extract the word under cursor
          local word_start = line:sub(1, col):match(".*()%S+$") or col
          local word_end = line:sub(col + 1):match("^%S+()") or (col + 1)
          if not word_start then
            word_start = col
          end
          if not word_end then
            word_end = col + 1
          else
            word_end = word_end + col
          end
          
          local word = line:sub(word_start, word_end)
          
          -- Check if it's a Jira issue key
          local project_key = config.get('project_key')
          local pattern = project_key and project_key .. "%-[0-9]+" or "[A-Z][A-Z0-9]+%-[0-9]+"
          
          if word:match(pattern) then
            local issue_key = word:match(pattern)
            
            -- Add Jira-specific code actions
            result = result or {}
            table.insert(result, {
              title = "View " .. issue_key .. " in Jira",
              kind = "quickfix",
              command = {
                command = "jira-nvim.view-issue",
                title = "View " .. issue_key,
                arguments = {issue_key}
              }
            })
            
            table.insert(result, {
              title = "Open " .. issue_key .. " in browser",
              kind = "quickfix",
              command = {
                command = "jira-nvim.open-issue",
                title = "Open " .. issue_key,
                arguments = {issue_key}
              }
            })
          end
          
          -- Call the original handler
          return old_handler(err, result, ctx, config)
        end
      end
    end,
    desc = "Add Jira code actions"
  })
  
  -- Register the commands
  vim.api.nvim_create_user_command("JiraViewIssueUnderCursor", function()
    local issue_key = context.get_issue_key_under_cursor()
    if issue_key then
      require('jira-nvim.cli').issue_view(issue_key)
    else
      utils.show_warning("No issue key found under cursor")
    end
  end, {
    desc = "View Jira issue under cursor"
  })
  
  vim.api.nvim_create_user_command("JiraOpenIssueUnderCursor", function()
    local issue_key = context.get_issue_key_under_cursor()
    if issue_key then
      require('jira-nvim.cli').open(issue_key)
    else
      utils.show_warning("No issue key found under cursor")
    end
  end, {
    desc = "Open Jira issue under cursor in browser"
  })
  
  -- Register LSP commands
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
      local bufnr = args.buf
      vim.lsp.commands["jira-nvim.view-issue"] = function(params)
        local issue_key = params.arguments[1]
        require('jira-nvim.cli').issue_view(issue_key)
      end
      
      vim.lsp.commands["jira-nvim.open-issue"] = function(params)
        local issue_key = params.arguments[1]
        require('jira-nvim.cli').open(issue_key)
      end
    end,
    desc = "Register Jira LSP commands"
  })
  
  utils.show_info("Jira code actions enabled")
end

-- Setup all LSP integrations
function M.setup()
  -- Check prerequisites
  if vim.fn.has('nvim-0.7') == 0 then
    utils.show_warning("Neovim 0.7+ required for LSP integration")
    return
  end
  
  -- Setup namespace
  M.namespace = vim.api.nvim_create_namespace('jira-nvim')
  
  -- Setup highlighting
  M.setup_highlighting()
  
  -- Setup hover handler
  M.setup_hover_handler()
  
  -- Setup code actions
  M.setup_code_actions()
  
  utils.show_info("Jira LSP integrations enabled")
end

return M