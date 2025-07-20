#!/bin/bash

# Run tests with coverage tracking
# Requires luarocks and luacov to be installed

set -e

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Check if lua is available
if ! command -v lua &> /dev/null; then
    echo "ERROR: Lua is not installed or not in PATH"
    exit 1
fi

# Check if luacov is installed
echo "Checking for LuaCov..."
lua -e "require('luacov')" 2>/dev/null || {
  echo "LuaCov not found. Please install with: luarocks install luacov"
  
  # Check if luarocks is installed
  if command -v luarocks &> /dev/null; then
    echo "Installing LuaCov with luarocks..."
    luarocks install --local luacov
  else
    echo "Luarocks not found. Please install luacov manually."
    echo "Running without coverage tracking..."
  fi
}

echo "Running tests with coverage tracking..."
cd "$PROJECT_DIR"
lua -lluacov "$PROJECT_DIR/scripts/run_coverage.lua"

# Check if coverage report was generated
if [ -f "$PROJECT_DIR/luacov.report.out" ]; then
  echo ""
  echo "Coverage report summary:"
  echo "========================"
  
  # Extract the summary from the report
  awk '/^Summary/{flag=1; next} /^[[:space:]]*$/{if (flag) exit} flag' "$PROJECT_DIR/luacov.report.out"
  
  echo ""
  echo "Full coverage report is available at: $PROJECT_DIR/luacov.report.out"
else
  echo "No coverage report was generated."
fi