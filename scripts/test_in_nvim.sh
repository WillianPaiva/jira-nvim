#!/bin/bash

# Run tests in a headless Neovim instance
# This uses Neovim's built-in Lua interpreter to run tests

# Make script exit on first error
set -e

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Use the first argument as test pattern or use default
TEST_PATTERN=${1:-"spec/*.lua"}

# Check if nvim is available
if ! command -v nvim &> /dev/null; then
    echo "ERROR: Neovim is not installed or not in PATH"
    exit 1
fi

echo "Running tests in Neovim with pattern: $TEST_PATTERN"

# Run tests in headless Neovim
nvim --headless \
  -c "set rtp+=${PROJECT_DIR}" \
  -c "lua package.path = package.path .. ';${PROJECT_DIR}/lua/?.lua;${PROJECT_DIR}/lua/?/init.lua;${PROJECT_DIR}/spec/mocks/?.lua'" \
  -c "lua require('vim_mock')" \
  -c "luafile ${PROJECT_DIR}/spec/cli_spec.lua" \
  -c "luafile ${PROJECT_DIR}/spec/cli_error_spec.lua" \
  -c "q!"