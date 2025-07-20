-- Minimal init.lua for testing
-- This file is used to start Neovim with minimal configuration

-- Set runtime path to include our plugin
vim.cmd([[set rtp+=/Users/willian.vervalempaiv/Projects/jira-nvim-plugin]])

-- Disable plugins
vim.loader = nil
vim.g.loaded_lazy = 1
vim.g.loaded_plugins = 1

-- Ensure we have access to the necessary paths
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua;./spec/mocks/?.lua'

-- Basic vim configuration
vim.cmd([[
  set noswapfile
  set nobackup
  set nowritebackup
  set noundofile
  set bufhidden=wipe
  syntax off
]])

print("Minimal config loaded successfully!")

-- Load the mocks
require('vim_mock')
require('busted_mock')

-- Run the tests
local function run_test_file(path)
  print("\nRunning tests from: " .. path)
  print("--------------------------------------")
  
  local success, result = pcall(dofile, path)
  
  if success then
    print("✅ Tests passed: " .. path)
    return true
  else
    print("❌ Tests failed: " .. path)
    print(result)
    return false
  end
end

local test_files = {
  "/Users/willian.vervalempaiv/Projects/jira-nvim-plugin/spec/cli_spec.lua",
  "/Users/willian.vervalempaiv/Projects/jira-nvim-plugin/spec/cli_error_spec.lua"
}

local passed = 0
local failed = 0

for _, file in ipairs(test_files) do
  if run_test_file(file) then
    passed = passed + 1
  else
    failed = failed + 1
  end
end

print("\n--------------------------------------")
print(string.format("Test results: %d passed, %d failed", passed, failed))
print("--------------------------------------")

-- Exit with appropriate status code
if failed > 0 then
  vim.cmd("cquit " .. failed)
else
  vim.cmd("qall!")