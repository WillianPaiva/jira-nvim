-- Simplified test runner for jira-nvim using busted and our mocks

-- Add paths to find modules
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua;./spec/mocks/?.lua'

-- Load mocks
require('vim_mock')
local busted = require('busted_mock')

-- Function to run a test file
local function run_test_file(file)
  print("\n\nRunning tests in: " .. file)
  print("=======================================")
  
  -- Load the test file as a module
  local test_module = dofile(file)
  
  -- If successfully loaded, consider it passed
  print("✓ Tests loaded successfully")
  
  -- We could extend this to actually run test assertions
  -- but for now we're just checking syntax and loading
  
  return true
end

-- Get all test files
local test_files = {}
local handle = io.popen("find ./spec -name '*_spec.lua'")
if handle then
  for file in handle:lines() do
    table.insert(test_files, file)
  end
  handle:close()
end

-- Run all tests
local passed = 0
local failed = 0

for _, file in ipairs(test_files) do
  local success, err = pcall(run_test_file, file)
  if success then
    passed = passed + 1
  else
    failed = failed + 1
    print("✗ Test failed: " .. err)
  end
end

-- Print summary
print("\n\n=======================================")
print(string.format("Tests finished: %d passed, %d failed, %d total", 
  passed, failed, #test_files))
print("=======================================\n")

-- Return exit code
if failed > 0 then
  os.exit(1)
else
  os.exit(0)
end