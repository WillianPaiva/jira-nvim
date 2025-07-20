-- Lua test runner with coverage for jira-nvim

package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua;./spec/mocks/?.lua'

-- Check if luacov is installed
local has_luacov, luacov = pcall(require, "luacov")
if not has_luacov then
  print("LuaCov not found. Please install it with: luarocks install luacov")
  print("Continuing without coverage...")
end

-- Load mocks and busted framework
require('vim_mock')
local busted = require('busted_mock')

-- Function to run tests with coverage
local function run_tests_with_coverage(test_files)
  if has_luacov then
    -- Start coverage
    luacov.start()
  end

  local passed = 0
  local failed = 0
  local total = 0

  for _, file_path in ipairs(test_files) do
    print("\n\n===================================================")
    print("Running tests from: " .. file_path)
    print("===================================================\n")
    
    local success, result = pcall(dofile, file_path)
    
    if success then
      print("\n✅ Tests loaded successfully from: " .. file_path)
      passed = passed + 1
    else
      print("\n❌ Tests failed in: " .. file_path)
      print(result)
      failed = failed + 1
    end
    total = total + 1
  end

  print("\n\n===================================================")
  print(string.format("Test results: %d passed, %d failed, %d total", passed, failed, total))
  print("===================================================\n")

  if has_luacov then
    -- Stop coverage
    luacov.shutdown()
    
    -- Generate report
    print("\nGenerating coverage report...")
    local report = require("luacov.reporter")
    report.report()
    print("\nCoverage report generated in luacov.report.out")
  end

  return failed == 0
end

-- Collect test files
local test_files = {
  "./spec/cli_spec.lua",
  "./spec/cli_error_spec.lua"
}

-- Run tests
local success = run_tests_with_coverage(test_files)

-- Exit with appropriate code
os.exit(success and 0 or 1)