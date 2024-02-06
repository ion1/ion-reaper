local Misc = require("lib.misc")

local Slope = {}

function Slope.extrapolate(time, value, slope, new_time)
  return value + (new_time - time) * slope
end

function Slope.is_redundant(prev_time, prev_value, prev_slope, time, value, slope)
  local result = Misc.equals(prev_slope, slope)
    and Misc.equals(Slope.extrapolate(prev_time, prev_value, prev_slope, time), value)

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

function Slope.intersection_time(a_time, a_value, a_slope, b_time, b_value, b_slope)
  if math.abs(a_slope - b_slope) < 1e-6 then
    return nil
  end

  local time = ((b_value - b_time * b_slope) - (a_value - a_time * a_slope)) / (a_slope - b_slope)
  return time
end

return Slope
