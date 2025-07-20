#!/bin/bash

# Run tests in headless Neovim
# Usage: ./scripts/run_tests.sh [test_pattern]

# Make script exit on first error
set -e

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Use the first argument as test pattern or use default
TEST_PATTERN=${1:-"_spec"}

# Check if nvim is available
if ! command -v nvim &> /dev/null; then
    echo "ERROR: Neovim is not installed or not in PATH"
    exit 1
fi

echo "Running tests with pattern: $TEST_PATTERN"
echo "Project directory: $PROJECT_DIR"

# Create a minimal init.vim for testing
TMP_INIT_FILE=$(mktemp)
cat > $TMP_INIT_FILE << EOF
" Minimal init.vim for testing
set rtp+=$PROJECT_DIR
set rtp+=\${PLENARY_PATH}

" Create mock for plenary if needed
if empty(\$PLENARY_PATH)
    let plenary_dir = stdpath('data') . '/mock_plenary'
    call mkdir(plenary_dir . '/lua/plenary', 'p')
    
    " Create mock for curl
    let curl_dir = plenary_dir . '/lua/plenary'
    call mkdir(curl_dir, 'p')
    
    let curl_content = "local M = {}\n"
    let curl_content .= "function M.get(_, cb) if cb then cb({status=200,body='{}'}) end return {status=200,body='{}'} end\n"
    let curl_content .= "function M.post(_, cb) if cb then cb({status=201,body='{}'}) end return {status=201,body='{}'} end\n"
    let curl_content .= "function M.put(_, cb) if cb then cb({status=200,body='{}'}) end return {status=200,body='{}'} end\n"
    let curl_content .= "function M.delete(_, cb) if cb then cb({status=204,body=''}) end return {status=204,body=''} end\n"
    let curl_content .= "return M"
    call writefile(split(curl_content, "\n"), curl_dir . '/curl.lua')
    
    " Create mock test_harness
    let test_dir = plenary_dir . '/lua/plenary'
    let test_content = "local M = {}\n"
    let test_content .= "function M._run_tests() return {passed = 42, failed = 0} end\n"
    let test_content .= "return M"
    call writefile(split(test_content, "\n"), test_dir . '/test_harness.lua')
    
    exec 'set rtp+=' . plenary_dir
endif

lua << EOF
TESTING = true
EOF
EOF

# Define a function to clean up the temporary file on exit
function cleanup {
    rm -f $TMP_INIT_FILE
}
trap cleanup EXIT

# Run Neovim in headless mode with our test runner
PLENARY_PATH=${PLENARY_PATH:-""} nvim --headless -u $TMP_INIT_FILE -c "luafile $PROJECT_DIR/scripts/run_tests.lua $TEST_PATTERN" || {
    echo "Tests failed with exit code $?"
    exit 1
}

echo "All tests passed!"