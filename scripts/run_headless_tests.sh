#!/bin/bash

# Run tests in headless Neovim with minimal configuration
# Usage: ./scripts/run_headless_tests.sh

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "Running tests in headless Neovim..."
echo "Project directory: $PROJECT_DIR"

# Run Neovim with minimal init file
nvim --headless -u "$PROJECT_DIR/scripts/minimal_init.lua" -c "quit"
exit_code=$?

if [ $exit_code -eq 0 ]; then
  echo "All tests passed!"
else
  echo "Tests failed with exit code: $exit_code"
  exit $exit_code
fi