local Misc = require("lib.misc")

local MIDIMPEInitialValues = {}

local function hex_dump(str)
  local hex_values = {}

  for ix = 1, #str do
    table.insert(hex_values, string.format("%02x", string.byte(str, ix)))
  end

  return table.concat(hex_values, " ")
end

function MIDIMPEInitialValues.process_take(take, move_initial_values_after_note_on)
  local ok, midi_buf = reaper.MIDI_GetAllEvts(take)
  if not ok then
    error("MIDI_GetAllEvts failed")
  end

  local events = MIDIMPEInitialValues.parse_events(midi_buf)

  for ch = 0, 15 do
    events.channel[ch] = MIDIMPEInitialValues.move_initial_values(
      events.channel[ch],
      move_initial_values_after_note_on
    )
  end

  local midi_buf = MIDIMPEInitialValues.serialize_events(events)
  local ok = reaper.MIDI_SetAllEvts(take, midi_buf)
  if not ok then
    error("MIDI_SetAllEvts failed")
  end
end

function MIDIMPEInitialValues.parse_events(midi_buf)
  local channel_events = {}
  local global_events = {}

  for ch = 0, 15 do
    channel_events[ch] = {}
  end

  local pos = 1
  local ppq_pos = 0
  local last_bezier_event = nil

  while pos <= midi_buf:len() do
    local ppq_offset, flag, msg, next_pos = string.unpack("i4Bs4", midi_buf, pos)
    if not ppq_offset or not flag or not msg or not next_pos then
      break
    end

    ppq_pos = ppq_pos + ppq_offset
    -- local time = reaper.MIDI_GetProjTimeFromPPQPos(take, ppq_pos)

    local status = msg:byte(1)
    if status == nil then
      Misc.debug("(empty) time: %d, flag: %s", ppq_pos, flag)
      goto next
    elseif status >= 0x80 and status < 0xf0 then
      -- Channel event.
      local channel = status & 0xf
      Misc.debug("(channel) time: %d, flag: %s, channel: %s, msg: %s", ppq_pos, flag, tostring(channel), hex_dump(msg))

      local events = channel_events[channel]
      events[#events + 1] = { ppq_pos = ppq_pos, flag = flag, msg = msg }

      if flag & 0x50 == 0x50 then
        -- Bezier event.
        last_bezier_event = { channel = channel, ppq_pos = ppq_pos }
      end
    elseif status == 0xff and msg:sub(2, 6) == "\x0fCCBZ" then
      -- Bezier curve data.
      if last_bezier_event == nil or last_bezier_event.ppq_pos ~= ppq_pos then
        error("Bezier curve data without a corresponding Bezier event")
      end

      local channel = last_bezier_event.channel

      Misc.debug("(bezier) time: %d, flag: %s, channel: %s, msg: %s", ppq_pos, flag, tostring(channel), hex_dump(msg))

      local events = channel_events[channel]
      events[#events + 1] = { ppq_pos = ppq_pos, flag = flag, msg = msg }
    else
      -- Global event.
      Misc.debug("(global) time: %d, flag: %s, msg: %s", ppq_pos, flag, hex_dump(msg))

      global_events[#global_events + 1] = { ppq_pos = ppq_pos, flag = flag, msg = msg }
    end

    ::next::

    pos = next_pos
  end

  return {
    channel = channel_events,
    global = global_events,
  }
end

function MIDIMPEInitialValues.move_initial_values(channel_events, after_note_on)
  local result = {}
  local notes_playing = {}

  -- The channel control events which happened before a Note On while a note was
  -- not playing, or on the same PPQ position as a Note On after the Note On
  -- event.
  local control_events = {}
  local note_on_events = {}

  -- The PPQ position of the Note On event.
  local note_on_ppq_pos = nil

  function flush_queues()
    if not after_note_on then
      for _, event in ipairs(control_events) do
        result[#result + 1] = {
          ppq_pos = note_on_ppq_pos ~= nil and note_on_ppq_pos - 1 or event.ppq_pos,
          flag = event.flag,
          msg = event.msg,
        }
      end

      control_events = {}
    end

    for _, event in ipairs(note_on_events) do
      result[#result + 1] = event
    end

    note_on_events = {}

    if after_note_on then
      for _, event in ipairs(control_events) do
        result[#result + 1] = {
          ppq_pos = note_on_ppq_pos ~= nil and note_on_ppq_pos or event.ppq_pos,
          flag = event.flag,
          msg = event.msg,
        }
      end

      control_events = {}
    end

    note_on_ppq_pos = nil
  end

  for _, event in ipairs(channel_events) do
    Misc.debug("Event: ppq_pos: %s, flag: %s, msg: %s", event.ppq_pos, event.flag, hex_dump(event.msg))

    if note_on_ppq_pos ~= nil and event.ppq_pos > note_on_ppq_pos then
      flush_queues()
    end

    local status = event.msg:byte(1)

    if status & 0xf0 == 0x90 then
      -- Note On
      Misc.debug("Note On")

      notes_playing[event.msg:byte(2)] = true
      note_on_ppq_pos = event.ppq_pos

      note_on_events[#note_on_events + 1] = event
    elseif status & 0xf0 == 0x80 then
      -- Note Off
      Misc.debug("Note Off")

      notes_playing[event.msg:byte(2)] = nil
      flush_queues()

      result[#result + 1] = event
    else
      -- Other message.
      Misc.debug("Other event")

      control_events[#control_events + 1] = event
    end
  end

  flush_queues()

  -- Verify that we did not mess up the event order.
  local prev_ppq_pos = 0
  for _, event in ipairs(result) do
    if event.ppq_pos < prev_ppq_pos then
      error(
        string.format(
          "Internal error: Generated an event at %d after an event at %d",
          event.ppq_pos,
          prev_ppq_pos
        )
      )
    end

    prev_ppq_pos = event.ppq_pos
  end

  return result
end

function MIDIMPEInitialValues.serialize_events(events)
  local merged_events = {}

  for _, event in ipairs(events.global) do
    merged_events[#merged_events + 1] = event
  end

  for ch = 0, 15 do
    for _, event in ipairs(events.channel[ch]) do
      merged_events[#merged_events + 1] = event
    end
  end

  table.sort(merged_events, function(a, b)
    return a.ppq_pos < b.ppq_pos
  end)

  local midi_buf_entries = {}

  local last_ppq_pos = 0
  for _, event in ipairs(merged_events) do
    local ppq_offset = event.ppq_pos - last_ppq_pos
    local serialized = string.pack("i4Bs4", ppq_offset, event.flag, event.msg)
    midi_buf_entries[#midi_buf_entries + 1] = serialized

    last_ppq_pos = event.ppq_pos
  end

  return table.concat(midi_buf_entries)
end

return MIDIMPEInitialValues
