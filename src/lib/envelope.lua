local Misc = require("lib.misc")

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
    if prev and Misc.is_redundant(prev.time, prev.value, prev.slope, time, value, slope) then
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
    if prev and Misc.is_redundant(prev.time, prev.value, prev.slope, time, value, slope) then
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
    if next and Misc.is_redundant(time, value, slope, next.time, next.value, next.slope) then
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
    error(string.format("Internal error: Invalid search result: %s, %s", ix, match))
  end

  local next = self:lookup(self.cursor + 1)
  if next and Misc.is_redundant(time, value, slope, next.time, next.value, next.slope) then
    -- The change has made the next element redundant. Remove it.
    table.remove(self.table, self.cursor + 1)
    self.last_ix = self.last_ix - 1
  end
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
    error(string.format("Internal error: Invalid match result: %s", match))
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
    error(
      string.format("Internal error: Binary search failed (%s, %s, %s)", first_ix, last_ix, time)
    )
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
    error(string.format("Internal error: Invalid match result: %s", match))
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
