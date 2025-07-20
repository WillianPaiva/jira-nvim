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