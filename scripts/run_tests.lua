-- Test runner script for jira-nvim

local has_plenary, plenary = pcall(require, "plenary")
if not has_plenary then
  print("Plenary.nvim is required to run tests. Please install it.")
  vim.cmd("quit!")
  return
end

-- Load the Plenary test harness
local harness = require("plenary.test_harness")

-- Define tests to run (all files matching this pattern will be executed)
local test_pattern = "%_spec"
if vim.fn.argv()[1] then
  test_pattern = vim.fn.argv()[1]
end

-- Show output
print("\n\n=============================================")
print("Running tests matching pattern: " .. test_pattern)
print("=============================================\n")

-- Run the tests
local results = harness._run_tests(
  vim.fn.getcwd() .. "/spec",
  {
    pattern = test_pattern,
    sequential = true,  -- Run tests sequentially
    timeout = 30000,    -- 30 second timeout
  }
)

-- Show summary
local passed = results.passed
local failed = results.failed
local total = passed + failed
print("\n\n=============================================")
print(string.format("Tests finished: %d passed, %d failed, %d total", 
  passed, failed, total))
print("=============================================\n")

-- Exit with error code if tests failed
if failed > 0 then
  vim.cmd("cquit " .. failed)
else
  vim.cmd("quit!")
end