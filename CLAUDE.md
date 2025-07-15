# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains **jira-nvim**, a Neovim Lua plugin that provides seamless integration with Jira. The plugin communicates directly with the Jira REST API, allowing you to manage Jira issues, projects, sprints, and more directly from within Neovim.

## Architecture

### Plugin Architecture (`lua/jira-nvim/`)

The plugin follows a modular architecture with clear separation of concerns:

- **`init.lua`**: Entry point that registers all Neovim user commands (`:JiraIssueList`, `:JiraIssueView`, etc.)
- **`config.lua`**: Configuration management with defaults for window behavior, keymaps, API credentials, and secure storage
- **`api.lua`**: Core module that handles direct communication with the Jira REST API
- **`cli.lua`**: Command interface layer that processes user commands and calls the API module
- **`ui.lua`**: User interface layer handling floating/split windows, keymaps, and content display
- **`utils.lua`**: Utility functions for validation, formatting, and user feedback
- **`user.lua`**: User-related functionality and caching
- **`search.lua`**: Search functionality and history management
- **`form.lua`**: Form interfaces for creating issues and other actions

### API Integration Pattern

The plugin directly communicates with Jira's REST API:
1. User runs Neovim command (e.g., `:JiraIssueList`)
2. `cli.lua` processes the command and calls the appropriate `api.lua` function
3. `api.lua` makes the HTTP request to the Jira REST API using plenary.curl
4. The response is formatted and displayed via `ui.lua` windows
5. Interactive keymaps allow navigation and further actions on results

## Development Commands

### For Plugin Development
The Neovim plugin requires no build step as it's pure Lua. Testing involves:

1. Install the plugin in Neovim test environment
2. Configure Jira credentials using the setup wizard or manually
3. Test commands: `:JiraIssueList`, `:JiraIssueView PROJ-123`, etc.

## Key Integration Points

- **API Authentication**: Handled by `api.lua` which manages Basic Auth with username/API token
- **Credential Storage**: Securely stores API credentials in Neovim's config directory
- **Response Formatting**: API responses are formatted into human-readable text before display
- **Async Execution**: All API calls run asynchronously to avoid blocking Neovim
- **Error Handling**: API errors are caught and displayed as Neovim notifications

## Plugin Configuration

Users configure the plugin via `require('jira-nvim').setup({})` with options for:
- Jira URL (`jira_url`)
- Jira email (`jira_email`)
- Jira API token (`jira_api_token`)
- Default project key (`project_key`)
- Window behavior (floating vs split, dimensions)
- Custom keymaps for navigation
- API timeout settings

## API Endpoints Used

The plugin uses various Jira REST API endpoints, including but not limited to:

- `/rest/api/3/issue`: For getting, creating, and updating issues
- `/rest/api/3/search`: For searching issues with JQL
- `/rest/api/3/project`: For listing and accessing projects
- `/rest/api/3/myself`: For getting current user information
- `/rest/api/3/user/search`: For finding users (e.g., for assigning issues)
- `/rest/agile/1.0/board`: For accessing board data
- `/rest/agile/1.0/sprint`: For working with sprints

## Dependencies

- **plenary.nvim**: Used for its curl library to make HTTP requests
- **telescope.nvim**: Optional, for enhanced search functionality

No external CLI tools are required - the plugin works directly with the Jira API.