local Misc = {}

local DEBUGGING = false

-- luacov: disable
if DEBUGGING then
  if reaper then
    function Misc.debug(fmt, ...)
      reaper.ShowConsoleMsg(string.format(fmt .. "\n", ...))
    end
  else
    function Misc.debug(fmt, ...)
      print(string.format(fmt, ...))
    end
  end
else
  function Misc.debug(fmt, ...) end
end
-- luacov: enable

function Misc.almost_equals(a, b, eps)
  eps = eps or 1e-6

  local scale = math.max(1.0, math.abs(a), math.abs(b))

  return math.abs(b - a) < scale * eps
end

-- List the byte values within a string separated by spaces.
function Misc.bytes(str)
  return table.concat({ string.byte(str, 0, -1) }, " ")
end

-- Returns each previous_value, value where previous_value is {} on the first iteration
-- and value is {} on the last iteration.
function Misc.adjacent_pairs(iter, iter_arg, iter_state)
  return coroutine.wrap(function()
    local previous_value = {}

    while true do
      local value = { iter(iter_arg, iter_state) }
      iter_state = value[1]
      if not iter_state then
        if previous_value[1] then
          -- The previous one was the final value. Yield one more pair.
          coroutine.yield(previous_value, {})
        end
        break
      end

      coroutine.yield(previous_value, value)

      previous_value = value
    end
  end)
end

-- Convert a MIDI pitch value into a string such as "C4(+25)"
function Misc.midi_pitch_string(midi_pitch)
  local octave_table = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }

  local rounded_midi_pitch = math.ceil(midi_pitch - 0.5)

  local note_in_octave = rounded_midi_pitch % 12
  local octave = (rounded_midi_pitch // 12) - 1

  local fraction = midi_pitch - rounded_midi_pitch
  local cents = fraction * 100

  return string.format("%s%d(%+03.0f)", octave_table[note_in_octave + 1], octave, cents)
end

function Misc.midi_pitch_to_frequency(midi_pitch)
  return 440.0 * 2.0 ^ ((midi_pitch - 69) / 12.0)
end

local LOG_2 = math.log(2.0)
local INV_LOG_2 = 1.0 / LOG_2

function Misc.frequency_to_midi_pitch(frequency)
  return 12.0 * math.log(frequency / 440.0) * INV_LOG_2 + 69
end

return Misc
