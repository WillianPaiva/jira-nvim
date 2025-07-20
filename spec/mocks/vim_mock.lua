-- Mock the vim global for tests
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

-- Simple stub/unstub implementation
local stubbed = {}

function stub(obj, key, impl)
  if not stubbed[obj] then stubbed[obj] = {} end
  stubbed[obj][key] = { original = obj[key] }
  obj[key] = impl or function() end
  return obj[key]
end

function unstub(obj, key)
  if stubbed[obj] and stubbed[obj][key] then
    obj[key] = stubbed[obj][key].original
    stubbed[obj][key] = nil
  end
end

-- Handle global unstub calls
_G.unstub = unstub

return _G.vim