# Changelog

All notable changes to jira-nvim will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive documentation in `docs/DOCUMENTATION.md` and `docs/API.md`
- Contribution guide in `CONTRIBUTING.md`
- Changelog to track version history

### Fixed
- Fixed initialization error in user module that caused startup errors
- Fixed cache statistics showing error when UI module wasn't properly imported

## [1.1.0] - 2023-07-15

### Added
- **Enhanced Form Interface**:
  - Live markdown preview with `<C-p>` toggle in issue creation form
  - Issue type templates with `<C-t>` in issue creation form
  - Smart field autocompletion for assignee, components, and more
  - Better form navigation and field detection
- **Personalized Dashboard**:
  - Comprehensive dashboard view with `:JiraDashboard`
  - Personal statistics with `:JiraStats`
  - View of assigned issues by status, sprint items, recent activity
- **Context Awareness**:
  - Auto-detection of issue keys in git branches, commits, and files
  - Quick issue lookup from current context with `:JiraContext`
  - Direct commands to view and open issue under cursor
- **Git Integration**:
  - Branch creation from Jira issues with `:JiraGitBranch`
  - Commit history with Jira issue links via `:JiraGitCommitHistory`
  - Automatic linking of commits to issues
  - Git hooks for workflow automation
- **LSP Integration**:
  - Hover tooltips for issue keys in code
  - Code actions for Jira issues
  - Issue key highlighting with `:JiraHighlightKeys`
- **Performance Optimization**:
  - Smart caching system for API responses
  - Cache statistics and management via `:JiraCacheStats`
  - Background data fetching for issue lists
- **Error Handling**:
  - Friendly error messages with troubleshooting tips
  - Comprehensive troubleshooting guide with `:JiraTroubleshoot`

### Changed
- Improved command organization and consistency
- Enhanced README with better documentation and examples
- Better visualization with icons and formatting

### Fixed
- Multiple bug fixes and stability improvements

## [1.0.0] - 2023-05-01

### Added
- Initial release of jira-nvim plugin
- Basic Jira issue management via Neovim
- Issue listing and filtering
- Issue creation and viewing
- Sprint and project management
- Configuration system for Jira credentials