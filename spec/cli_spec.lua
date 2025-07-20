package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua;./spec/mocks/?.lua'

-- Load mocks
require('vim_mock')

-- Now load the module under test
local cli = require('jira-nvim.cli')

describe("jira-nvim CLI module", function()
  local config, api, utils, ui

  setup(function()
    config = require("jira-nvim.config")
    api = require("jira-nvim.api")
    utils = require("jira-nvim.utils")
    ui = require("jira-nvim.ui")

    -- Mock config responses
    stub(config, "get", function(key)
      if key == "project_key" or key == "default_project" then return "PROJ" end
      if key == "max_results" then return 25 end
      if key == "jira_url" then return "https://jira.example.com" end
    end)

    stub(utils, "is_api_available", function() return true end)
    stub(utils, "create_spinner", function() return { stop = function() end } end)
    stub(utils, "validate_issue_key", function(issue_key) 
      if issue_key and issue_key:match("^%w+%-%d+$") then
        return true, nil
      else
        return false, "Invalid issue key format: " .. (issue_key or "nil")
      end
    end)
    stub(utils, "parse_api_response", function(data, type)
      if not data then return "Empty data" end
      if data.key then return "Formatted output: " .. data.key end
      if data[1] and data[1].key then return "Formatted output: " .. data[1].key end
      if data.values and data.values[1] and data.values[1].name then 
        return "Formatted output: " .. data.values[1].name
      end
      return "Formatted output: mock data"
    end)
    stub(utils, "show_error")
    stub(utils, "show_warning")
    stub(utils, "show_info")
    stub(utils, "open_in_browser")
    stub(vim.fn, "input", function(prompt) return "dummy input" end)

    -- API mocks for successful responses
    stub(api, "search_issues", function(jql, _, callback) callback(nil, { { key = "PROJ-123" } }) end)
    stub(api, "create_issue", function(_, _, _, _, _, callback) callback(nil, { key = "PROJ-999" }) end)
    stub(api, "get_issue", function(_, callback) callback(nil, { key = "PROJ-123", fields = {} }) end)
    stub(api, "get_boards", function(callback) callback(nil, { { id = 1, name = "Board X" } }) end)
    stub(api, "get_sprints", function(_, callback) callback(nil, { { id = 2, name = "Sprint 1" } }) end)
    stub(api, "get_epics", function(_, callback) callback(nil, { { id = 3, name = "Epic 1" } }) end)
    stub(api, "get_projects", function(callback) callback(nil, { { key = "PROJ", name = "Project X" } }) end)
    stub(api, "get_project_boards", function(_, callback) callback(nil, { { id = 4, name = "Board Y" } }) end)
    stub(api, "get_active_sprint", function(_, callback) callback(nil, { values = { { id = 5, name = "Sprint Y", goal = "Deliver Y" } } }) end)
    stub(api, "get_transitions", function(_, callback) callback(nil, { transitions = { { id = "10", name = "Done" }, { id = "11", name = "In Progress" } } }) end)
    stub(api, "transition_issue", function(_, _, _, _, callback) callback(nil, { success = true }) end)
    stub(api, "add_comment", function(_, _, callback) callback(nil, { id = "comment-1" }) end)
    stub(api, "assign_issue", function(_, _, callback) callback(nil, { success = true }) end)
    stub(api, "add_watcher", function(_, _, callback) callback(nil, { success = true }) end)
    stub(api, "get_current_user", function(callback) callback(nil, { accountId = "user-123", displayName = "Test User" }) end)
    stub(api, "find_users", function(_, callback) callback(nil, { { accountId = "user-456", displayName = "Found User" } }) end)

    stub(ui, "show_output")
  end)

  it("lists issues with default project", function()
    cli.issue_list("")
    assert.stub(ui.show_output).was_called()
  end)

  it("creates an issue with full args", function()
    cli.issue_create('-p"PROJ" -t"Bug" -s"Test bug" -d"desc"')
    assert.stub(utils.show_info).was_called_with("Issue created: PROJ-999")
  end)

  it("views a specific issue", function()
    cli.issue_view("PROJ-123")
    assert.stub(ui.show_output).was_called()
  end)

  it("lists sprints", function()
    cli.sprint_list("")
    assert.stub(ui.show_output).was_called()
  end)

  it("lists epics", function()
    cli.epic_list("")
    assert.stub(ui.show_output).was_called()
  end)

  it("opens homepage if no issue key given", function()
    cli.open("")
    assert.stub(utils.open_in_browser).was_called_with("https://jira.example.com")
  end)

  it("opens project URL if non-issue key", function()
    cli.open("PROJ")
    assert.stub(utils.open_in_browser).was_called_with("https://jira.example.com/projects/PROJ")
  end)

  it("lists projects", function()
    cli.project_list()
    assert.stub(ui.show_output).was_called()
  end)

  it("lists boards for project", function()
    cli.project_boards()
    assert.stub(ui.show_output).was_called()
  end)

  it("shows current sprint issues", function()
    cli.current_sprint()
    assert.stub(ui.show_output).was_called()
  end)
  
  -- New tests for improved coverage
  it("lists issues with JQL query", function()
    cli.issue_list('-q"project = PROJ AND status = \'In Progress\'"')
    assert.stub(ui.show_output).was_called()
  end)
  
  it("lists issues with multiple conditions", function()
    cli.issue_list('-p"PROJ" -s"In Progress" -a"currentUser()"')
    assert.stub(ui.show_output).was_called()
  end)
  
  it("shows warning for invalid issue key", function()
    cli.issue_view("invalid-key")
    assert.stub(utils.show_warning).was_called()
  end)
  
  it("lists all boards", function()
    cli.board_list()
    assert.stub(ui.show_output).was_called()
  end)
  
  it("lists boards for specific project", function()
    cli.board_list("CUSTOM")
    assert.stub(ui.show_output).was_called()
  end)
  
  it("gets available transitions for an issue", function()
    local callback_called = false
    cli.get_available_transitions("PROJ-123", function(err, transitions)
      assert.is_nil(err)
      assert.is_table(transitions)
      callback_called = true
    end)
    assert.is_true(callback_called)
  end)
  
  it("transitions an issue to a new state", function()
    cli.issue_transition("PROJ-123", "Done", "Completed the task", nil, nil)
    assert.stub(utils.show_info).was_called_with("Issue PROJ-123 transitioned to \"Done\"")
  end)
  
  it("adds a comment to an issue", function()
    cli.issue_comment_add("PROJ-123", "This is a test comment")
    assert.stub(utils.show_info).was_called_with("Comment added to issue PROJ-123")
  end)
  
  it("rejects empty comment", function()
    cli.issue_comment_add("PROJ-123", "")
    assert.stub(utils.show_warning).was_called_with("Comment body is required")
  end)
  
  it("adds comment from buffer", function()
    cli.issue_comment_add_from_buffer("PROJ-123", 0) -- 0 is buffer number
    assert.stub(utils.show_info).was_called_with("Comment added to issue PROJ-123")
  end)
  
  it("assigns an issue to a user", function()
    cli.issue_assign("PROJ-123", "john.doe")
    assert.stub(utils.show_info).was_called()
  end)
  
  it("assigns an issue to current user with 'me' alias", function()
    cli.issue_assign("PROJ-123", "me")
    assert.stub(utils.show_info).was_called()
  end)
  
  it("unassigns an issue", function()
    cli.issue_assign("PROJ-123", "none")
    assert.stub(utils.show_info).was_called_with("Issue PROJ-123 assigned to unassigned")
  end)
  
  it("adds current user as watcher", function()
    cli.issue_watch("PROJ-123")
    assert.stub(utils.show_info).was_called_with("Added watcher to issue PROJ-123")
  end)
  
  it("adds specific user as watcher", function()
    cli.issue_watch("PROJ-123", "jane.doe")
    assert.stub(utils.show_info).was_called_with("Added watcher to issue PROJ-123")
  end)
  
  it("gets current user information", function()
    local callback_called = false
    cli.get_current_user(function(err, user)
      assert.is_nil(err)
      assert.equal("user-123", user.accountId)
      callback_called = true
    end)
    assert.is_true(callback_called)
  end)
  
  -- Error handling tests
  it("handles API errors in issue_list", function()
    stub(api, "search_issues", function(_, _, callback) callback("API Error", nil) end)
    cli.issue_list("")
    assert.stub(utils.show_error).was_called()
    unstub(api.search_issues)
    -- Restore original stub
    stub(api, "search_issues", function(jql, _, callback) callback(nil, { { key = "PROJ-123" } }) end)
  end)
  
  it("handles API errors in issue_view", function()
    stub(api, "get_issue", function(_, callback) callback("API Error", nil) end)
    cli.issue_view("PROJ-123")
    assert.stub(utils.show_error).was_called()
    unstub(api.get_issue)
    -- Restore original stub
    stub(api, "get_issue", function(_, callback) callback(nil, { key = "PROJ-123", fields = {} }) end)
  end)
  
  it("handles API errors in issue_create", function()
    stub(api, "create_issue", function(_, _, _, _, _, callback) callback("API Error", nil) end)
    cli.issue_create('-p"PROJ" -t"Bug" -s"Test bug"')
    assert.stub(utils.show_error).was_called()
    unstub(api.create_issue)
    -- Restore original stub
    stub(api, "create_issue", function(_, _, _, _, _, callback) callback(nil, { key = "PROJ-999" }) end)
  end)

  teardown(function()
    unstub(config.get)
    unstub(api.search_issues)
    unstub(api.create_issue)
    unstub(api.get_issue)
    unstub(api.get_boards)
    unstub(api.get_sprints)
    unstub(api.get_epics)
    unstub(api.get_projects)
    unstub(api.get_project_boards)
    unstub(api.get_active_sprint)
    unstub(api.get_transitions)
    unstub(api.transition_issue)
    unstub(api.add_comment)
    unstub(api.assign_issue)
    unstub(api.add_watcher)
    unstub(api.get_current_user)
    unstub(api.find_users)
    unstub(utils.is_api_available)
    unstub(utils.create_spinner)
    unstub(utils.parse_api_response)
    unstub(utils.show_error)
    unstub(utils.show_warning)
    unstub(utils.show_info)
    unstub(utils.open_in_browser)
    unstub(utils.validate_issue_key)
    unstub(ui.show_output)
    unstub(vim.fn.input)
  end)
end)
