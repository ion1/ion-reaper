local Misc = require("lib.misc")

local ReaperUtils = {}

function ReaperUtils.message(fmt, ...)
  reaper.ShowConsoleMsg(string.format(fmt .. "\n", ...))
end

function ReaperUtils.selected_media_item_iterator(project)
  return coroutine.wrap(function()
    local count = reaper.CountSelectedMediaItems(project)

    for i = 0, count - 1 do
      coroutine.yield(reaper.GetSelectedMediaItem(project, i))
    end
  end)
end

-- Split consecutive notes into segments whenever there is a pause between notes.
function ReaperUtils.lowest_note_segment_iterator(media_item)
  return coroutine.wrap(function()
    local current_segment

    local function add_note(note)
      current_segment.end_time = note.end_time
      local notes = current_segment.notes
      notes[#notes + 1] = note
    end

    local function new_segment(last_note, next_note)
      if current_segment then
        current_segment.next_segment_start_time = next_note and next_note.start_time
        coroutine.yield(current_segment)
      end

      if not next_note then
        current_segment = nil
      else
        current_segment = {
          start_time = next_note.start_time,
          end_time = next_note.end_time,
          previous_segment_end_time = last_note and last_note.end_time,
          next_segment_start_time = nil,
          notes = {},
        }
      end
    end

    for prev_note_t, note_t in Misc.adjacent_pairs(ReaperUtils.lowest_note_iterator(media_item)) do
      local prev_note, note = prev_note_t[1], note_t[1]

      if not prev_note then
        -- The first note of the first segment.
        new_segment(nil, note)
      end

      if prev_note and note and note.start_time - prev_note.end_time >= 0.1 then
        -- There is a pause between the notes.
        new_segment(prev_note, note)
      end

      if note then
        add_note(note)
      else
        -- The previous note was the final note of the final segment. Yield the segment.
        new_segment(prev_note, nil)
      end
    end
  end)
end

-- Returns start_time, end_time, pitch for each lowest note.
function ReaperUtils.lowest_note_iterator(media_item)
  return coroutine.wrap(function()
    local last_note = nil

    for time, pitch in ReaperUtils.lowest_pitch_playing_iterator(media_item) do
      if not last_note then
        if pitch then
          -- Note started.
          last_note = { time = time, pitch = pitch }
        end
      else
        if not pitch then
          -- Note ended.
          local output = { start_time = last_note.time, end_time = time, pitch = last_note.pitch }
          coroutine.yield(output)
          last_note = nil
        elseif pitch ~= last_note.pitch then
          -- Note changed.
          local output = { start_time = last_note.time, end_time = time, pitch = last_note.pitch }
          coroutine.yield(output)
          last_note = { time = time, pitch = pitch }
        end
      end
    end

    if last_note then
      error("End of lowest_pitch_playing_iterator while a note is still playing")
    end
  end)
end

-- Returns time, pitch|nil for the lowest pitch (if any) at each time it changes.
function ReaperUtils.lowest_pitch_playing_iterator(media_item)
  return coroutine.wrap(function()
    local last_pitch = nil

    for time, pitches_playing in ReaperUtils.pitches_playing_iterator(media_item) do
      local pitch = nil
      for pitch_playing, _ in pairs(pitches_playing) do
        if not pitch or pitch_playing < pitch then
          pitch = pitch_playing
        end
      end

      if pitch ~= last_pitch then
        last_pitch = pitch
        coroutine.yield(time, pitch)
      end
    end
  end)
end

-- Returns time, { [midi_pitch] = true } with all the notes playing at each time they
-- change.
function ReaperUtils.pitches_playing_iterator(media_item)
  return coroutine.wrap(function()
    local take = reaper.GetActiveTake(media_item)

    local ok, midi_buf = reaper.MIDI_GetAllEvts(take)
    if not ok then
      error("MIDI_GetAllEvts failed")
    end

    local pitches_playing = {}

    for time, flag, msg in ReaperUtils.midi_event_iterator(take, midi_buf) do
      if flag & 2 ~= 0 then
        -- muted
        goto continue
      end

      local msg_type = msg:byte(1) >> 4
      local is_note_on = msg_type == 0x9 and msg:byte(3) > 0
      local is_note_off = msg_type == 0x8 or (msg_type == 0x9 and msg:byte(3) == 0)

      if is_note_on then
        local pitch = msg:byte(2)
        if not pitches_playing[pitch] then
          pitches_playing[pitch] = true
          coroutine.yield(time, pitches_playing)
        end
      elseif is_note_off then
        local pitch = msg:byte(2)
        if pitches_playing[pitch] then
          pitches_playing[pitch] = nil
          coroutine.yield(time, pitches_playing)
        end
      end

      ::continue::
    end
  end)
end

-- Returns offset, flag, msg for each MIDI event in the buffer.
function ReaperUtils.midi_event_iterator(take, midi_buf)
  return coroutine.wrap(function()
    local pos = 1

    local ppq_pos = 0

    while pos <= midi_buf:len() do
      local ppq_offset, flag, msg, next_pos = string.unpack("i4Bs4", midi_buf, pos)
      if not ppq_offset or not flag or not msg or not next_pos then
        return
      end

      ppq_pos = ppq_pos + ppq_offset
      local time = reaper.MIDI_GetProjTimeFromPPQPos(take, ppq_pos)

      coroutine.yield(time, flag, msg)

      pos = next_pos
    end
  end)
end

return ReaperUtils
