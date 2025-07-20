package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua;./spec/mocks/?.lua'

-- Load mocks
require('vim_mock')

-- Now load the module under test
local cli = require('jira-nvim.cli')

describe("jira-nvim CLI module error handling", function()
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
    stub(utils, "parse_api_response", function(data, type) return "Formatted output" end)
    stub(utils, "show_error")
    stub(utils, "show_warning")
    stub(utils, "show_info")
    stub(utils, "open_in_browser")
    stub(utils, "validate_issue_key", function(issue_key) 
      if issue_key and issue_key:match("^%w+%-%d+$") then
        return true, nil
      else
        return false, "Invalid issue key format: " .. (issue_key or "nil")
      end
    end)
    
    stub(vim.fn, "input", function(prompt) return "dummy input" end)
    
    -- API error mocks - all return errors
    stub(api, "search_issues", function(jql, _, callback) callback("API Error: search_issues", nil) end)
    stub(api, "create_issue", function(_, _, _, _, _, callback) callback("API Error: create_issue", nil) end)
    stub(api, "get_issue", function(_, callback) callback("API Error: get_issue", nil) end)
    stub(api, "get_boards", function(callback) callback("API Error: get_boards", nil) end)
    stub(api, "get_sprints", function(_, callback) callback("API Error: get_sprints", nil) end)
    stub(api, "get_epics", function(_, callback) callback("API Error: get_epics", nil) end)
    stub(api, "get_projects", function(callback) callback("API Error: get_projects", nil) end)
    stub(api, "get_project_boards", function(_, callback) callback("API Error: get_project_boards", nil) end)
    stub(api, "get_active_sprint", function(_, callback) callback("API Error: get_active_sprint", nil) end)
    stub(api, "get_transitions", function(_, callback) callback("API Error: get_transitions", nil) end)
    stub(api, "transition_issue", function(_, _, _, _, callback) callback("API Error: transition_issue", nil) end)
    stub(api, "add_comment", function(_, _, callback) callback("API Error: add_comment", nil) end)
    stub(api, "assign_issue", function(_, _, callback) callback("API Error: assign_issue", nil) end)
    stub(api, "add_watcher", function(_, _, callback) callback("API Error: add_watcher", nil) end)
    stub(api, "get_current_user", function(callback) callback("API Error: get_current_user", nil) end)
    stub(api, "find_users", function(_, callback) callback("API Error: find_users", nil) end)

    stub(ui, "show_output")
  end)

  -- Error handling tests
  it("handles API errors in issue_list", function()
    cli.issue_list("")
    assert.stub(utils.show_error).was_called_with(match.is_string())
  end)

  it("handles API errors in issue_view", function()
    cli.issue_view("PROJ-123")
    assert.stub(utils.show_error).was_called_with(match.is_string())
  end)

  it("handles API errors in issue_create", function()
    cli.issue_create('-p"PROJ" -t"Bug" -s"Test bug"')
    assert.stub(utils.show_error).was_called_with(match.is_string())
  end)

  it("handles API errors in sprint_list", function()
    cli.sprint_list("")
    assert.stub(utils.show_error).was_called_with(match.is_string())
  end)

  it("handles API errors in epic_list", function()
    cli.epic_list("")
    assert.stub(utils.show_error).was_called_with(match.is_string())
  end)

  it("handles API errors in project_list", function()
    cli.project_list()
    assert.stub(utils.show_error).was_called_with(match.is_string())
  end)

  it("handles API errors in project_boards", function()
    cli.project_boards()
    assert.stub(utils.show_error).was_called_with(match.is_string())
  end)

  it("handles API errors in current_sprint", function()
    cli.current_sprint()
    assert.stub(utils.show_error).was_called_with(match.is_string())
  end)

  it("handles API errors in board_list", function()
    cli.board_list("PROJ")
    assert.stub(utils.show_error).was_called_with(match.is_string())
  end)

  it("handles API errors in issue_transition", function()
    cli.issue_transition("PROJ-123", "Done")
    assert.stub(utils.show_error).was_called_with(match.is_string())
  end)

  it("handles API errors in issue_comment_add", function()
    cli.issue_comment_add("PROJ-123", "test comment")
    assert.stub(utils.show_error).was_called_with(match.is_string())
  end)

  it("handles API errors in issue_assign", function()
    cli.issue_assign("PROJ-123", "user")
    assert.stub(utils.show_error).was_called_with(match.is_string())
  end)

  it("handles API errors in issue_watch", function()
    cli.issue_watch("PROJ-123")
    assert.stub(utils.show_error).was_called_with(match.is_string())
  end)

  it("handles API unavailable", function()
    stub(utils, "is_api_available", function() return false end)
    cli.issue_list("")
    assert.stub(utils.show_error).was_called_with('Jira API not configured. Please set your Jira credentials first.')
    unstub(utils.is_api_available)
    stub(utils, "is_api_available", function() return true end)
  end)

  it("handles transitions not available", function()
    unstub(api.get_transitions)
    stub(api, "get_transitions", function(_, callback) callback(nil, {}) end)
    cli.issue_transition("PROJ-123", "Done")
    assert.stub(utils.show_error).was_called_with(match.is_string())
    unstub(api.get_transitions)
    stub(api, "get_transitions", function(_, callback) callback("API Error: get_transitions", nil) end)
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