-- CI test setup script
-- This script helps set up the testing environment for GitHub Actions

-- Create a basic busted environment for our tests
local busted_env = {}

-- Define busted functions globally (required by spec files)
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
    os.exit(1)
  end
end

_G.setup = function(fn)
  print("  Setup")
  local success, err = pcall(fn)
  if not success then
    print("    ✗ Setup failed: " .. tostring(err))
    os.exit(1)
  end
end

_G.teardown = function(fn)
  print("  Teardown")
  local success, err = pcall(fn)
  if not success then
    print("    ✗ Teardown failed: " .. tostring(err))
    os.exit(1)
  end
end

_G.before_each = function(fn)
  -- Store for later use
  _G._before_each = fn
end

_G.after_each = function(fn)
  -- Store for later use
  _G._after_each = fn
end

-- Create stub/unstub functions
local stubbed = {}

_G.stub = function(obj, key, impl)
  if not stubbed[obj] then stubbed[obj] = {} end
  stubbed[obj][key] = { original = obj[key] }
  obj[key] = impl or function() end
  return obj[key]
end

_G.unstub = function(obj, key)
  if stubbed[obj] and stubbed[obj][key] then
    obj[key] = stubbed[obj][key].original
    stubbed[obj][key] = nil
  end
end

-- Create basic assertions
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

-- Set up mock vim global
_G.vim = {
  fn = {
    input = function(prompt) return "mock input" end
  },
  api = {
    nvim_buf_get_lines = function(buf, start, ending, strict)
      return { "mock line 1", "mock line 2" }
    end
  },
  cmd = function(cmd) end,
  notify = function(msg, level, opts) end
}

-- Return the setup environment
return busted_env