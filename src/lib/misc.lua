local Misc = {}

local DEBUGGING = false

function Misc.equals(a, b, eps)
  eps = eps or 1e-6

  local scale = math.max(1.0, math.abs(a), math.abs(b))

  return math.abs(b - a) < scale * eps
end

function Misc.debug(fmt, ...)
  if DEBUGGING then
    print(string.format(fmt, ...))
  end
end

return Misc
