local M = {}

local config = require('jira-nvim.config')
local cli = require('jira-nvim.cli')
local utils = require('jira-nvim.utils')

local function create_issue_form()
  local buf = vim.api.nvim_create_buf(false, true)
  
  local width = math.floor(vim.o.columns * 0.6)
  local height = math.floor(vim.o.lines * 0.7)
  
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    border = 'rounded',
    title = ' Create Jira Issue ',
    title_pos = 'center'
  })
  
  local template = {
    "# Jira Issue Creation Form",
    "# Fill out the details below and press <leader>js to submit",
    "# Press 'q' to cancel",
    "",
    "## Required Fields",
    "Type: Bug",
    "Summary: ",
    "",
    "## Optional Fields", 
    "Priority: Medium",
    "Assignee: ",
    "Labels: ",
    "Components: ",
    "Fix Version: ",
    "",
    "## Description",
    "# Write your issue description below this line",
    "",
  }
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, template)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  
  -- Position cursor at the summary field
  vim.api.nvim_win_set_cursor(win, {7, 9}) -- Line 7, after "Summary: "
  vim.cmd('startinsert!')
  
  -- Set keymaps for the form
  local opts = { noremap = true, silent = true, buffer = buf }
  
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, vim.tbl_extend('force', opts, { desc = 'Cancel issue creation' }))
  
  vim.keymap.set('n', '<leader>js', function()
    M.submit_issue_form(buf, win)
  end, vim.tbl_extend('force', opts, { desc = 'Submit issue' }))
  
  vim.keymap.set('i', '<C-s>', function()
    M.submit_issue_form(buf, win)
  end, vim.tbl_extend('force', opts, { desc = 'Submit issue' }))
  
  -- Add helpful instructions at the bottom
  vim.api.nvim_echo({
    { "Fill out the form and press ", "Normal" },
    { "<leader>js", "Special" },
    { " to create the issue, or ", "Normal" },
    { "q", "Special" },
    { " to cancel", "Normal" }
  }, false, {})
end

function M.submit_issue_form(buf, win)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  
  local issue_data = {}
  local description_start = nil
  
  -- Parse the form
  for i, line in ipairs(lines) do
    if line:match("^Type:%s*(.+)") then
      issue_data.type = line:match("^Type:%s*(.+)")
    elseif line:match("^Summary:%s*(.+)") then
      issue_data.summary = line:match("^Summary:%s*(.+)")
    elseif line:match("^Priority:%s*(.+)") then
      issue_data.priority = line:match("^Priority:%s*(.+)")
    elseif line:match("^Assignee:%s*(.+)") then
      issue_data.assignee = line:match("^Assignee:%s*(.+)")
    elseif line:match("^Labels:%s*(.+)") then
      issue_data.labels = line:match("^Labels:%s*(.+)")
    elseif line:match("^Components:%s*(.+)") then
      issue_data.components = line:match("^Components:%s*(.+)")
    elseif line:match("^Fix Version:%s*(.+)") then
      issue_data.fix_version = line:match("^Fix Version:%s*(.+)")
    elseif line:match("^# Write your issue description below this line") then
      description_start = i + 1
    end
  end
  
  -- Collect description
  if description_start then
    local description_lines = {}
    for i = description_start, #lines do
      if lines[i] and not lines[i]:match("^#") then
        table.insert(description_lines, lines[i])
      end
    end
    issue_data.description = table.concat(description_lines, '\n'):gsub("^%s*(.-)%s*$", "%1")
  end
  
  -- Validate required fields
  if not issue_data.type or issue_data.type == "" then
    utils.show_error("Type is required")
    return
  end
  
  if not issue_data.summary or issue_data.summary == "" then
    utils.show_error("Summary is required")
    return
  end
  
  -- Build command arguments
  local args = {}
  
  table.insert(args, string.format('-t"%s"', issue_data.type))
  table.insert(args, string.format('-s"%s"', issue_data.summary))
  
  if issue_data.priority and issue_data.priority ~= "" and issue_data.priority ~= "Medium" then
    table.insert(args, string.format('-y"%s"', issue_data.priority))
  end
  
  if issue_data.assignee and issue_data.assignee ~= "" then
    table.insert(args, string.format('-a"%s"', issue_data.assignee))
  end
  
  if issue_data.labels and issue_data.labels ~= "" then
    for label in issue_data.labels:gmatch("[^,]+") do
      local trimmed_label = label:gsub("^%s*(.-)%s*$", "%1")
      if trimmed_label ~= "" then
        table.insert(args, string.format('-l"%s"', trimmed_label))
      end
    end
  end
  
  if issue_data.components and issue_data.components ~= "" then
    for component in issue_data.components:gmatch("[^,]+") do
      local trimmed_component = component:gsub("^%s*(.-)%s*$", "%1")
      if trimmed_component ~= "" then
        table.insert(args, string.format('-C"%s"', trimmed_component))
      end
    end
  end
  
  if issue_data.fix_version and issue_data.fix_version ~= "" then
    table.insert(args, string.format('--fix-version "%s"', issue_data.fix_version))
  end
  
  if issue_data.description and issue_data.description ~= "" then
    table.insert(args, string.format('-b"%s"', issue_data.description:gsub('"', '\\"')))
  end
  
  table.insert(args, '--no-input')
  
  local cmd_args = table.concat(args, ' ')
  
  -- Close the form window
  vim.api.nvim_win_close(win, true)
  
  -- Show what command will be executed
  utils.show_info("Creating issue with: jira issue create " .. cmd_args)
  
  -- Execute the command
  cli.issue_create(cmd_args)
end

function M.create_issue()
  create_issue_form()
end

local function create_issue_list_form()
  local buf = vim.api.nvim_create_buf(false, true)
  
  local width = math.floor(vim.o.columns * 0.6)
  local height = math.floor(vim.o.lines * 0.6)
  
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    border = 'rounded',
    title = ' Filter Jira Issues ',
    title_pos = 'center'
  })
  
  local template = {
    "# Jira Issue List Filter",
    "# Fill out the filters below and press <leader>js to search",
    "# Press 'q' to cancel, leave fields empty to ignore them",
    "",
    "## Common Filters",
    "Assignee: $(jira me)",
    "Status: ",
    "Priority: ",
    "Type: ",
    "Labels: ",
    "Components: ",
    "",
    "## Time Filters",
    "Created: ",
    "Updated: ",
    "Created Before: ",
    "",
    "## Advanced",
    "JQL Query: ",
    "Order By: created",
    "Reverse Order: false",
    "",
    "# Examples:",
    "# Assignee: $(jira me), username, or 'x' for unassigned",
    "# Status: \"To Do\", \"In Progress\", \"Done\"",
    "# Priority: Low, Medium, High, Critical",
    "# Type: Bug, Story, Task, Epic",
    "# Created: -7d, week, month, -1h, -30m",
    "# Labels: backend,frontend (comma separated)",
  }
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, template)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  
  -- Position cursor at the assignee field
  vim.api.nvim_win_set_cursor(win, {6, 19}) -- Line 6, after "Assignee: $(jira me)"
  vim.cmd('startinsert!')
  
  -- Set keymaps for the form
  local opts = { noremap = true, silent = true, buffer = buf }
  
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, vim.tbl_extend('force', opts, { desc = 'Cancel filter' }))
  
  vim.keymap.set('n', '<leader>js', function()
    M.submit_issue_list_form(buf, win)
  end, vim.tbl_extend('force', opts, { desc = 'Apply filters' }))
  
  vim.keymap.set('i', '<C-s>', function()
    M.submit_issue_list_form(buf, win)
  end, vim.tbl_extend('force', opts, { desc = 'Apply filters' }))
end

function M.submit_issue_list_form(buf, win)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  
  local filters = {}
  
  -- Parse the form
  for i, line in ipairs(lines) do
    if line:match("^Assignee:%s*(.+)") then
      local assignee = line:match("^Assignee:%s*(.+)")
      if assignee then
        assignee = assignee:gsub("^%s*(.-)%s*$", "%1")
        if assignee ~= "" then
          filters.assignee = assignee
        end
      end
    elseif line:match("^Status:%s*(.+)") then
      local status = line:match("^Status:%s*(.+)")
      if status then
        status = status:gsub("^%s*(.-)%s*$", "%1")
        if status ~= "" then
          filters.status = status
        end
      end
    elseif line:match("^Priority:%s*(.+)") then
      local priority = line:match("^Priority:%s*(.+)")
      if priority then
        priority = priority:gsub("^%s*(.-)%s*$", "%1")
        if priority ~= "" then
          filters.priority = priority
        end
      end
    elseif line:match("^Type:%s*(.+)") then
      local issue_type = line:match("^Type:%s*(.+)")
      if issue_type then
        issue_type = issue_type:gsub("^%s*(.-)%s*$", "%1")
        if issue_type ~= "" then
          filters.type = issue_type
        end
      end
    elseif line:match("^Labels:%s*(.+)") then
      local labels = line:match("^Labels:%s*(.+)")
      if labels then
        labels = labels:gsub("^%s*(.-)%s*$", "%1")
        if labels ~= "" then
          filters.labels = labels
        end
      end
    elseif line:match("^Components:%s*(.+)") then
      local components = line:match("^Components:%s*(.+)")
      if components then
        components = components:gsub("^%s*(.-)%s*$", "%1")
        if components ~= "" then
          filters.components = components
        end
      end
    elseif line:match("^Created:%s*(.+)") then
      local created = line:match("^Created:%s*(.+)")
      if created then
        created = created:gsub("^%s*(.-)%s*$", "%1")
        if created ~= "" then
          filters.created = created
        end
      end
    elseif line:match("^Updated:%s*(.+)") then
      local updated = line:match("^Updated:%s*(.+)")
      if updated then
        updated = updated:gsub("^%s*(.-)%s*$", "%1")
        if updated ~= "" then
          filters.updated = updated
        end
      end
    elseif line:match("^Created Before:%s*(.+)") then
      local created_before = line:match("^Created Before:%s*(.+)")
      if created_before then
        created_before = created_before:gsub("^%s*(.-)%s*$", "%1")
        if created_before ~= "" then
          filters.created_before = created_before
        end
      end
    elseif line:match("^JQL Query:%s*(.+)") then
      local jql = line:match("^JQL Query:%s*(.+)")
      if jql then
        jql = jql:gsub("^%s*(.-)%s*$", "%1")
        if jql ~= "" then
          filters.jql = jql
        end
      end
    elseif line:match("^Order By:%s*(.+)") then
      local order_by = line:match("^Order By:%s*(.+)")
      if order_by then
        order_by = order_by:gsub("^%s*(.-)%s*$", "%1")
        if order_by ~= "" and order_by ~= "created" then
          filters.order_by = order_by
        end
      end
    elseif line:match("^Reverse Order:%s*(.+)") then
      local reverse = line:match("^Reverse Order:%s*(.+)")
      if reverse and reverse:lower() == "true" then
        filters.reverse = true
      end
    end
  end
  
  -- Build command arguments
  local args = {}
  
  if filters.assignee then
    table.insert(args, string.format('-a"%s"', filters.assignee))
  end
  
  if filters.status then
    table.insert(args, string.format('-s"%s"', filters.status))
  end
  
  if filters.priority then
    table.insert(args, string.format('-y"%s"', filters.priority))
  end
  
  if filters.type then
    table.insert(args, string.format('-t"%s"', filters.type))
  end
  
  if filters.labels then
    for label in filters.labels:gmatch("[^,]+") do
      local trimmed_label = label:gsub("^%s*(.-)%s*$", "%1")
      if trimmed_label ~= "" then
        table.insert(args, string.format('-l"%s"', trimmed_label))
      end
    end
  end
  
  if filters.components then
    for component in filters.components:gmatch("[^,]+") do
      local trimmed_component = component:gsub("^%s*(.-)%s*$", "%1")
      if trimmed_component ~= "" then
        table.insert(args, string.format('-C"%s"', trimmed_component))
      end
    end
  end
  
  if filters.created then
    table.insert(args, string.format('--created "%s"', filters.created))
  end
  
  if filters.updated then
    table.insert(args, string.format('--updated "%s"', filters.updated))
  end
  
  if filters.created_before then
    table.insert(args, string.format('--created-before "%s"', filters.created_before))
  end
  
  if filters.jql then
    table.insert(args, string.format('-q "%s"', filters.jql))
  end
  
  if filters.order_by then
    table.insert(args, string.format('--order-by "%s"', filters.order_by))
  end
  
  if filters.reverse then
    table.insert(args, '--reverse')
  end
  
  local cmd_args = table.concat(args, ' ')
  
  -- Close the form window
  vim.api.nvim_win_close(win, true)
  
  -- Show what command will be executed
  utils.show_info("Listing issues with: jira issue list " .. cmd_args)
  
  -- Execute the command
  cli.issue_list(cmd_args)
end

function M.list_issues()
  create_issue_list_form()
end

-- Quick preset functions for common use cases
function M.my_issues()
  cli.issue_list('-a$(jira me)')
end

function M.my_todo_issues()
  cli.issue_list('-a$(jira me) -s"To Do"')
end

function M.my_in_progress_issues()
  cli.issue_list('-a$(jira me) -s"In Progress"')
end

function M.recent_issues()
  cli.issue_list('--created -7d')
end

function M.unassigned_issues()
  cli.issue_list('-ax')
end

function M.high_priority_issues()
  cli.issue_list('-yHigh')
end

return M