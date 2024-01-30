local Misc = {}

local DEBUGGING = false

function Misc.equals(a, b, eps)
  eps = eps or 1e-6

  local scale = math.max(1.0, math.abs(a), math.abs(b))

  return math.abs(b - a) < scale * eps
end

function Misc.extrapolate(time, value, slope, new_time)
  return value + (new_time - time) * slope
end

function Misc.is_redundant(prev_time, prev_value, prev_slope, time, value, slope)
  local result = Misc.equals(prev_slope, slope)
    and Misc.equals(Misc.extrapolate(prev_time, prev_value, prev_slope, time), value)

  if result then
    Misc.debug(
      "Redundant element: %s %s %s | %s %s %s",
      prev_time,
      prev_value,
      prev_slope,
      time,
      value,
      slope
    )
  end

  return result
end

function Misc.intersection_time(a_time, a_value, a_slope, b_time, b_value, b_slope)
  if math.abs(a_slope - b_slope) < 1e-6 then
    return nil
  end

  local time = ((b_value - b_time * b_slope) - (a_value - a_time * a_slope)) / (a_slope - b_slope)
  return time
end

function Misc.debug(fmt, ...)
  if DEBUGGING then
    print(string.format(fmt, ...))
  end
end

return Misc
