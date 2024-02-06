local Misc = require("lib.misc")
local Slope = require("lib.slope")

local Match = {
  -- The searched time matches the current envelope point exactly.
  SameTime = 0,
  -- The searched time is between the previous and the next envelope points.
  During = 1,
  -- The searched time is before the current envelope point.
  Before = 2,
  -- The searched time is at the next envelope point or later.
  After = 3,
}

local Envelope = {}
Envelope.__index = Envelope

function Envelope.new()
  local self = setmetatable({}, Envelope)

  -- An array of { time, value, slope } ordered by time.
  self.table = {}
  -- The final index of the array.
  self.last_ix = 0
  -- The previously modified index. Used to optimize for the presumption that
  -- almost every modification to the table occurs at an index next to or close
  -- to the previous one.
  self.cursor = 0

  return self
end

function Envelope:add(time, value, slope)
  Misc.debug("add(%s, %s, %s)", time, value, slope)

  if self.last_ix == 0 then
    -- Empty table.
    self.last_ix = self.last_ix + 1
    self.cursor = self.cursor + 1
    self.table[self.cursor] = { time, value, slope }
    return
  end

  -- Non-empty table.

  local ix, match = self:search(self.cursor, time)
  if match == Match.SameTime then
    local prev = self:lookup(ix - 1)
    if prev and Slope.is_redundant(prev.time, prev.value, prev.slope, time, value, slope) then
      -- Redundant element. Remove it.
      table.remove(self.table, ix)
      self.cursor = ix - 1
      self.last_ix = self.last_ix - 1
    else
      -- Replace the element.
      self.table[ix] = { time, value, slope }
      self.cursor = ix
    end
  elseif match == Match.During then
    local prev = self:lookup(ix)
    if prev and Slope.is_redundant(prev.time, prev.value, prev.slope, time, value, slope) then
      -- Redundant element. Skip adding it.
      self.cursor = ix
    else
      -- Insert after the element.
      table.insert(self.table, ix + 1, { time, value, slope })
      self.cursor = ix + 1
      self.last_ix = self.last_ix + 1
    end
  elseif ix == 1 and match == Match.Before then
    local next = self:lookup(ix)
    if next and Slope.is_redundant(time, value, slope, next.time, next.value, next.slope) then
      -- Replace the first element which would become redundant.
      self.table[ix] = { time, value, slope }
      self.cursor = ix
    else
      -- Insert before the first element.
      table.insert(self.table, ix, { time, value, slope })
      self.cursor = ix
      self.last_ix = self.last_ix + 1
    end
  else
    -- luacov: disable
    error(string.format("Internal error: Invalid search result: %s, %s", ix, match))
    -- luacov: enable
  end

  local next = self:lookup(self.cursor + 1)
  if next and Slope.is_redundant(time, value, slope, next.time, next.value, next.slope) then
    -- The change has made the next element redundant. Remove it.
    table.remove(self.table, self.cursor + 1)
    self.last_ix = self.last_ix - 1
  end
end

-- Merge another table of elements onto the envelope based on the lowest value at any
-- given time.
--
-- A ceiling parameter will result in the processing stopping as soon as the final
-- element of the input has been processed if that element has a value matching the
-- ceiling parameter and a zero slope.
--
-- If no existing elements in the envelope after the time of the element in question
-- exceed the ceiling, going through all of them would be redundant.
--
-- It is your responsibility to ensure that no input values exceed the ceiling when
-- using the ceiling option.
function Envelope:merge(elements, options)
  local ceiling = options and options.ceiling

  if self.last_ix == 0 then
    -- Our table is empty, add verbatim.
    for _, elem in ipairs(elements) do
      self:add(table.unpack(elem))
    end

    return
  end

  local their_ix = 1
  local their = self:unpack(elements[their_ix])
  if not their then
    return
  end
  local their_next = self:unpack(elements[their_ix + 1])

  local our_ix, match = self:search(self.cursor, their.time)
  self.cursor = our_ix

  if match == Match.SameTime or match == Match.During then
    Misc.debug("merge: match: SameTime or During")
  elseif our_ix == 1 and match == Match.Before then
    Misc.debug("merge: match: Before")
    our_ix = 0
  else
    -- luacov: disable
    error(string.format("Internal error: Invalid search result: ix=%s, match=%s", our_ix, match))
    -- luacov: enable
  end

  local our = self:lookup(our_ix)
  local our_next = self:lookup(our_ix + 1)

  if not our and not our_next then
    -- luacov: disable
    error(string.format("Internal error: no our and no our_next: ix=%s, match=%s", our_ix, match))
    -- luacov: enable
  end

  local to_be_added = {}

  local time = their.time

  while time do
    Misc.debug("merge: Iteration")
    Misc.debug("merge:   time=%s", time)
    Misc.debug(
      "merge:   Their: ix=%s time=%s value=%s slope=%s next_time=%s",
      their_ix,
      their.time,
      their.value,
      their.slope,
      their_next and their_next.time
    )
    Misc.debug(
      "merge:   Our: ix=%s time=%s value=%s slope=%s next_time=%s",
      our_ix,
      our and our.time,
      our and our.value,
      our and our.slope,
      our_next and our_next.time
    )

    local end_time
    if their_next and our_next then
      end_time = math.min(their_next.time, our_next.time)
    elseif their_next then
      end_time = their_next.time
    elseif our_next then
      end_time = our_next.time
    else
      end_time = nil
    end

    local intersection_time = our
      and Slope.intersection_time(
        their.time,
        their.value,
        their.slope,
        our.time,
        our.value,
        our.slope
      )
    Misc.debug("merge:   intersection_time=%s", intersection_time)

    if end_time then
      if intersection_time and time < intersection_time and intersection_time < end_time then
        Misc.debug("merge:   Lines intersect between points")
        -- The lines intersect between the existing points.
        end_time = intersection_time
      end
    else
      Misc.debug("merge:   Final element of both envelopes")
      if intersection_time and time < intersection_time then
        Misc.debug("merge:   Final lines intersect")
        end_time = intersection_time
      end
    end

    Misc.debug("merge:   end_time=%s", end_time)

    local elem
    if not our then
      Misc.debug("merge:   Using their envelope")
      elem = their
    else
      local discrimination_time
      if end_time then
        -- There may be an intersection at either `time` or `end_time`. Evaluate the
        -- lines at at a time between those to determine which one is lower.
        discrimination_time = (time + end_time) / 2.0
      else
        -- These are the final lines whose final possible intersection may be at `time`.
        -- Evaluate the lines at an arbitrary offset from `time` to determine which one
        -- is lower.
        discrimination_time = time + 1.0
      end

      Misc.debug("merge:   discrimination_time=%s", discrimination_time)

      local their_discr_value =
        Slope.extrapolate(their.time, their.value, their.slope, discrimination_time)
      local our_discr_value = Slope.extrapolate(our.time, our.value, our.slope, discrimination_time)

      Misc.debug(
        "merge:   their_discr_value=%s, our_discr_value=%s",
        their_discr_value,
        our_discr_value
      )

      if our_discr_value <= their_discr_value then
        Misc.debug("merge:   Using our envelope")
        elem = our
      else
        Misc.debug("merge:   Using their envelope")
        elem = their
      end
    end

    local value_at_time = Slope.extrapolate(elem.time, elem.value, elem.slope, time)
    Misc.debug("merge:   Add: time=%s value=%s slope=%s", time, value_at_time, elem.slope)
    to_be_added[#to_be_added + 1] = { time, value_at_time, elem.slope }

    if ceiling then
      if
        not their_next
        and (their.value >= ceiling or Misc.almost_equals(their.value, ceiling))
        and Misc.almost_equals(their.slope, 0)
      then
        Misc.debug("merge:   Their final element matches ceiling, stopping")
        break
      end
    end

    -- Advance things for the next iteration.

    time = end_time

    if their_next and time >= their_next.time then
      their_ix = their_ix + 1
      their = their_next
      their_next = self:unpack(elements[their_ix + 1])
    end

    if our_next and time >= our_next.time then
      our_ix = our_ix + 1
      our = our_next
      our_next = self:lookup(our_ix + 1)
    end
  end

  for _, elem in ipairs(to_be_added) do
    self:add(table.unpack(elem))
  end
end

-- Merge the given table of points to the envelope, computing the slopes between the
-- points automatically. The slope following the final point is assumed to be zero.
function Envelope:merge_points(points, options)
  local elements = {}

  local previous_time = nil
  local previous_value = nil

  for i, point in ipairs(points) do
    local time, value = table.unpack(point)

    if previous_time ~= nil and previous_value ~= nil then
      if Misc.almost_equals(previous_time, time) then
        error(
          string.format(
            "The times are equal, resulting in an infinite slope: %s, %s",
            previous_time,
            time
          )
        )
      end

      local slope = (value - previous_value) / (time - previous_time)
      elements[i - 1] = { previous_time, previous_value, slope }
    end

    previous_time, previous_value = time, value
  end

  elements[#points] = { previous_time, previous_value, 0 }

  self:merge(elements, options)
end

function Envelope:search(ix, time)
  Misc.debug("search(%s, %s)", ix, time)

  local match = self:match(ix, time)

  if match == Match.SameTime or match == Match.During then
    return ix, match
  elseif match == Match.Before then
    return self:exponential_search(ix, -1, time)
  elseif match == Match.After then
    return self:exponential_search(ix, 1, time)
  else
    -- luacov: disable
    error(string.format("Internal error: Invalid match result: %s", match))
    -- luacov: enable
  end
end

-- Search near the current ix first with the assumption that the common pattern
-- is to add many adjacent values. It is assumed that the element at the ix
-- parameter has already been checked not to match. Use a negative step size to
-- go backwards.
function Envelope:exponential_search(ix, step_size, time)
  local new_ix = math.min(math.max(ix + step_size, 1), self.last_ix)
  Misc.debug("exponential_search(%s, %s, %s) -> %s", ix, step_size, time, new_ix)

  local match = self:match(new_ix, time)

  local search_further = (match == Match.Before and step_size < 0)
    or (match == Match.After and step_size > 0)

  if match == Match.SameTime or match == Match.During then
    return new_ix, match
  elseif search_further then
    if match == Match.Before and new_ix == 1 then
      -- Already reached the beginning.
      return new_ix, match
    else
      return self:exponential_search(new_ix, step_size * 16, time)
    end
  else
    -- Went past the element, do a binary search within the last step.
    local first_ix, last_ix
    if step_size < 0 then
      first_ix, last_ix = new_ix + 1, ix - 1
    else
      first_ix, last_ix = ix + 1, new_ix - 1
    end
    return self:binary_search(first_ix, last_ix, time)
  end
end

function Envelope:binary_search(first_ix, last_ix, time)
  Misc.debug("binary_search(%s, %s, %s)", first_ix, last_ix, time)

  if first_ix > last_ix then
    -- luacov: disable
    error(
      string.format("Internal error: Binary search failed (%s, %s, %s)", first_ix, last_ix, time)
    )
    -- luacov: enable
  end

  local ix = (first_ix + last_ix) // 2
  local match = self:match(ix, time)

  if match == Match.SameTime or match == Match.During then
    return ix, match
  elseif match == Match.Before then
    return self:binary_search(first_ix, ix - 1, time)
  elseif match == Match.After then
    return self:binary_search(ix + 1, last_ix, time)
  else
    -- luacov: disable
    error(string.format("Internal error: Invalid match result: %s", match))
    -- luacov: enable
  end
end

-- An iterator which returns time, pitch, slope for each element in the envelope
function Envelope:elements()
  local ix = 1

  return function()
    if ix > self.last_ix then
      return nil
    end

    local current_ix = ix
    ix = ix + 1
    return table.unpack(self.table[current_ix])
  end
end

function Envelope:lookup(ix)
  return self:unpack(self.table[ix])
end

function Envelope:unpack(elem)
  return elem and {
    time = elem[1],
    value = elem[2],
    slope = elem[3],
  }
end

function Envelope:match(ix, time)
  local curr = self:lookup(ix)
  if not curr then
    error(string.format("No element at ix %s", ix))
  end

  local next = self:lookup(ix + 1)

  if time == curr.time then
    return Match.SameTime
  elseif time >= curr.time then
    if next and time >= next.time then
      return Match.After
    else
      return Match.During
    end
  elseif time < curr.time then
    return Match.Before
  end
end

return Envelope
