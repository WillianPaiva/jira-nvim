# Contributing to jira-nvim

Thank you for your interest in contributing to jira-nvim! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Environment](#development-environment)
4. [Coding Standards](#coding-standards)
5. [Pull Request Process](#pull-request-process)
6. [Testing](#testing)
7. [Documentation](#documentation)
8. [Release Process](#release-process)

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment. Be kind to others, be open to constructive criticism, and focus on what's best for the community.

## Getting Started

### Finding Issues to Work On

1. Look for issues labeled with `good first issue` for beginner-friendly tasks
2. Check issues labeled with `help wanted` for tasks where assistance is particularly welcome
3. Feel free to ask for guidance on any issue you're interested in

### Setting Up Your Fork

1. Fork the repository on GitHub
2. Clone your fork to your local machine:
   ```bash
   git clone https://github.com/YOUR-USERNAME/jira-nvim.git
   cd jira-nvim
   ```
3. Add the upstream repository as a remote:
   ```bash
   git remote add upstream https://github.com/WillianPaiva/jira-nvim.git
   ```
4. Create a new branch for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Environment

### Local Setup

For local development with LazyVim:

```lua
{
  dir = "/path/to/your/jira-nvim", -- Local development path
  name = "jira-nvim",
  dependencies = {
    "nvim-lua/plenary.nvim", -- For HTTP operations
  },
  opts = {
    -- Testing configuration
    jira_url = "https://your-domain.atlassian.net",
    jira_email = "your.email@example.com",
    jira_api_token = "your-api-token",
  },
  config = function(_, opts)
    require("jira-nvim").setup(opts)
  end,
}
```

### Debugging

Enable debug mode by setting:

```lua
vim.g.jira_nvim_debug = true
```

Debug logs will be written to `~/.cache/nvim/jira-nvim/debug.log`.

Use the `utils.debug()` function to add your own debug messages:

```lua
local utils = require('jira-nvim.utils')
utils.debug("This is a debug message")
utils.debug({ complex = "data", can = "be logged too" })
```

## Coding Standards

### Lua Style Guide

1. **Indentation**: Use 2 spaces for indentation (no tabs)
2. **Line Length**: Keep lines under 100 characters when possible
3. **Variable Naming**:
   - Use `snake_case` for variables and functions
   - Use `PascalCase` for classes and constructors
   - Use `UPPER_CASE` for constants
4. **Comments**:
   - Use `--` for single-line comments
   - Use `--[[` and `]]` for multi-line comments
   - Document functions with a brief description, parameters, and return values
5. **Module Structure**:
   - Use `local M = {}` pattern for modules
   - Return the module table at the end

### Example Code Style

```lua
local M = {}

-- Calculate the fibonacci number at position n
-- @param n (number) Position in fibonacci sequence
-- @return (number) The fibonacci number
function M.fibonacci(n)
  if n <= 1 then
    return n
  end
  
  return M.fibonacci(n - 1) + M.fibonacci(n - 2)
end

return M
```

### Code Organization

- Keep functions small and focused on a single responsibility
- Group related functions together
- Add clear section comments for different functional areas
- Place private helper functions above the functions that use them

## Pull Request Process

1. **Keep PRs Focused**:
   - Each PR should address a single concern
   - For multiple unrelated changes, submit separate PRs
   - Link to relevant issues with "Fixes #123" or "Relates to #456"

2. **PR Description**:
   - Clearly describe what changes you've made and why
   - Include steps to test your changes
   - Mention any breaking changes

3. **Code Review**:
   - Address review comments promptly
   - Ask for clarification if you don't understand feedback
   - Be open to suggestions and alternative approaches

4. **CI/Testing**:
   - Ensure all existing tests pass
   - Add new tests for your changes where appropriate
   - Manual testing for UI components is highly encouraged

5. **Updating PRs**:
   - Use `git pull --rebase upstream main` to keep your branch up to date
   - Force-push with `git push --force-with-lease` after rebasing

## Testing

Currently, jira-nvim lacks formal tests. Contributors are encouraged to:

1. Manually test their changes thoroughly
2. Consider adding tests using the busted framework (future goal)
3. Document test cases they've manually verified

### Manual Testing Checklist

- Functionality works as expected
- Error handling is in place
- Performance is acceptable
- UI is responsive and intuitive
- No regression in existing functionality

## Documentation

When making changes, please update the relevant documentation:

1. Update `README.md` for user-facing changes
2. Update `docs/DOCUMENTATION.md` for detailed feature documentation
3. Update `docs/API.md` for API changes
4. Add code comments for complex logic

Documentation should be clear, concise, and include examples where appropriate.

## Release Process

### Version Numbers

jira-nvim follows Semantic Versioning:

- **Major version**: Breaking changes
- **Minor version**: New features, non-breaking
- **Patch version**: Bug fixes, non-breaking

### Pre-release Steps

1. Update the version number in relevant files
2. Update CHANGELOG.md with notable changes
3. Ensure documentation is up to date
4. Run final testing to verify everything works

### Release Steps

1. Create a tagged release on GitHub
2. Include release notes describing the changes
3. Announce the release in relevant channels

---

Thank you for contributing to jira-nvim! Your efforts help make this plugin better for everyone.