#!/bin/bash

# Run mocked tests for jira-nvim
# This script uses our own mock system rather than requiring plenary

# Make script exit on first error
set -e

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Check if lua is available
if ! command -v lua &> /dev/null; then
    echo "ERROR: Lua is not installed or not in PATH"
    exit 1
fi

echo "Running mocked tests for jira-nvim"
echo "Project directory: $PROJECT_DIR"

# Change to project directory to ensure relative paths work
cd "$PROJECT_DIR"

# Run the test script
lua "$PROJECT_DIR/scripts/run_mock_tests.lua"