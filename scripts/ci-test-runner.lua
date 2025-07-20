#!/usr/bin/env lua

-- CI test runner script
-- This script runs tests in the GitHub Actions CI environment

-- Add lua paths
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua;./spec/mocks/?.lua;./scripts/?.lua'

-- Load test setup
require('ci-test-setup')

-- Create mock for plenary.curl
local mock_curl_dir = './spec/mocks/plenary'

-- Ensure curl mock directory exists
os.execute('mkdir -p ' .. mock_curl_dir)

-- Write curl mock file
local curl_mock_path = mock_curl_dir .. '/curl.lua'
local curl_mock_file = io.open(curl_mock_path, 'w')
if curl_mock_file then
  curl_mock_file:write([[
-- Mock implementation of plenary.curl for tests
local M = {}

function M.get(_, callback)
  if callback then
    callback({ status = 200, body = '{"success": true}' })
  end
  return { status = 200, body = '{"success": true}' }
end

function M.post(_, callback)
  if callback then
    callback({ status = 201, body = '{"success": true}' })
  end
  return { status = 201, body = '{"success": true}' }
end

function M.put(_, callback)
  if callback then
    callback({ status = 200, body = '{"success": true}' })
  end
  return { status = 200, body = '{"success": true}' }
end

function M.delete(_, callback)
  if callback then
    callback({ status = 204, body = '' })
  end
  return { status = 204, body = '' }
end

return M
]])
  curl_mock_file:close()
  print("Created mock for plenary.curl at: " .. curl_mock_path)
else
  print("Error: Could not create plenary.curl mock file")
  os.exit(1)
end

-- Function to run test files
local function run_test_file(file_path)
  print("\n===== Running tests for: " .. file_path .. " =====")
  
  local success, err = pcall(dofile, file_path)
  
  if success then
    print("✅ Tests passed for: " .. file_path)
    return true
  else
    print("❌ Tests failed for: " .. file_path .. ": " .. tostring(err))
    return false
  end
end

-- Get command line arguments
local test_files = {}
if #arg > 0 then
  for i=1, #arg do
    table.insert(test_files, arg[i])
  end
else
  -- Default test files
  test_files = {
    './spec/cli_spec.lua',
    './spec/cli_error_spec.lua'
  }
end

-- Run all test files
local passed = 0
local failed = 0

for _, file in ipairs(test_files) do
  if run_test_file(file) then
    passed = passed + 1
  else
    failed = failed + 1
  end
end

-- Show test summary
print("\n===== Test Summary =====")
print("Tests passed: " .. passed)
print("Tests failed: " .. failed)
print("Total tests:  " .. (passed + failed))
print("========================")

-- Exit with appropriate status code
os.exit(failed == 0 and 0 or 1)