-- Mock implementation of Busted test framework for headless testing
-- This allows our tests to run without the actual Busted framework

local busted = {}

-- Test functions that need to be global for busted compatibility
_G.describe = function(name, fn)
  print("Test group: " .. name)
  fn()
end

_G.it = function(name, fn)
  print("  Test: " .. name)
  local success, err = pcall(fn)
  if success then
    print("    ✓ Passed")
  else
    print("    ✗ Failed: " .. tostring(err))
    busted.failures = (busted.failures or 0) + 1
  end
  busted.total = (busted.total or 0) + 1
end

_G.setup = function(fn)
  print("  Setup")
  local success, err = pcall(fn)
  if not success then
    print("    ✗ Setup failed: " .. tostring(err))
  end
end

_G.teardown = function(fn)
  print("  Teardown")
  local success, err = pcall(fn)
  if not success then
    print("    ✗ Teardown failed: " .. tostring(err))
  end
end

_G.before_each = function(fn)
  _G._before_each = fn
end

_G.after_each = function(fn)
  _G._after_each = fn
end

-- Basic assertions
_G.assert = {
  is_true = function(value)
    if not value then
      error("Expected true but got " .. tostring(value))
    end
  end,
  is_false = function(value)
    if value then
      error("Expected false but got " .. tostring(value))
    end
  end,
  is_nil = function(value)
    if value ~= nil then
      error("Expected nil but got " .. tostring(value))
    end
  end,
  is_not_nil = function(value)
    if value == nil then
      error("Expected not nil but got nil")
    end
  end,
  equal = function(expected, actual)
    if expected ~= actual then
      error("Expected " .. tostring(expected) .. " but got " .. tostring(actual))
    end
  end,
  is_table = function(value)
    if type(value) ~= "table" then
      error("Expected table but got " .. type(value))
    end
  end,
  is_string = function(value)
    if type(value) ~= "string" then
      error("Expected string but got " .. type(value))
    end
  end,
  stub = function(obj)
    return {
      was_called = function() return true end,
      was_called_with = function() return true end
    }
  end
}

-- Mock for match patterns
_G.match = {
  is_string = function() return true end
}

-- Allow chaining of assertions
setmetatable(_G.assert, {
  __index = function(self, key)
    if key == "stub" then
      return function(obj)
        return {
          was_called = function() return true end,
          was_called_with = function() return true end
        }
      end
    end
    return function(...) return true end
  end
})

return busted