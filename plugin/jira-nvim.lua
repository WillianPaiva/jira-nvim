-- plugin/jira-nvim.lua
-- This file is automatically loaded by Neovim for proper plugin initialization

if vim.g.loaded_jira_nvim then
  return
end
vim.g.loaded_jira_nvim = 1

-- Plugin will be initialized via require('jira-nvim').setup() in user's config