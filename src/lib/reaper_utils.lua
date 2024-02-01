local ReaperUtils = {}

function ReaperUtils.message(fmt, ...)
  reaper.ShowConsoleMsg(string.format(fmt .. "\n", ...))
end

function ReaperUtils.selected_media_item_iterator(project)
  local count = reaper.CountSelectedMediaItems(project)
  local i = 0

  return function()
    if i > count then
      return nil
    end

    local current_i = i
    i = i + 1
    return reaper.GetSelectedMediaItem(project, current_i)
  end
end

-- Returns start_time, end_time, pitch for each lowest note.
function ReaperUtils.lowest_note_iterator(media_item)
  local next_lowest_pitch_playing = ReaperUtils.lowest_pitch_playing_iterator(media_item)

  local last_note = nil

  return function()
    while true do
      local time, pitch = next_lowest_pitch_playing()
      if not time then
        if last_note then
          error("End of lowest_pitch_playing_iterator while a note is still playing")
        end
        return
      end

      if not last_note then
        if pitch then
          -- Note started.
          last_note = { time = time, pitch = pitch }
        end
      else
        if not pitch then
          -- Note ended.
          local last_time, last_pitch = last_note.time, last_note.pitch
          last_note = nil
          return last_time, time, last_pitch
        elseif pitch ~= last_note.pitch then
          -- Note changed.
          local last_time, last_pitch = last_note.time, last_note.pitch
          last_note = { time = time, pitch = pitch }
          return last_time, time, last_pitch
        end
      end
    end
  end
end

-- Returns time, pitch|nil for the lowest pitch (if any) at each time it changes.
function ReaperUtils.lowest_pitch_playing_iterator(media_item)
  local next_pitches_playing = ReaperUtils.pitches_playing_iterator(media_item)

  local last_pitch = nil

  return function()
    while true do
      local time, pitches_playing = next_pitches_playing()
      if not time or not pitches_playing then
        return nil
      end

      local pitch = nil
      for pitch_playing, _ in pairs(pitches_playing) do
        if not pitch or pitch_playing < pitch then
          pitch = pitch_playing
        end
      end

      if pitch ~= last_pitch then
        last_pitch = pitch
        return time, pitch
      end
    end
  end
end

-- Returns time, { [midi_pitch] = true } with all the notes playing at each time they
-- change.
function ReaperUtils.pitches_playing_iterator(media_item)
  local take = reaper.GetActiveTake(media_item)

  local ok, midi_buf = reaper.MIDI_GetAllEvts(take)
  if not ok then
    error("MIDI_GetAllEvts failed")
  end

  local pitches_playing = {}

  local next_midi_evt = ReaperUtils.midi_event_iterator(take, midi_buf)
  local time = 0
  return function()
    local time, flag, msg

    while true do
      repeat
        time, flag, msg = next_midi_evt()
        if not time or not flag or not msg then
          return nil
        end
      until flag & 2 == 0 -- not muted

      local msg_type = msg:byte(1) >> 4
      local is_note_on = msg_type == 0x9 and msg:byte(3) > 0
      local is_note_off = msg_type == 0x8 or (msg_type == 0x9 and msg:byte(3) == 0)

      if is_note_on then
        local pitch = msg:byte(2)
        if not pitches_playing[pitch] then
          pitches_playing[pitch] = true
          return time, pitches_playing
        end
      elseif is_note_off then
        local pitch = msg:byte(2)
        if pitches_playing[pitch] then
          pitches_playing[pitch] = nil
          return time, pitches_playing
        end
      end
    end
  end
end

-- Returns offset, flag, msg for each MIDI event in the buffer.
function ReaperUtils.midi_event_iterator(take, midi_buf)
  local pos = 1

  local ppq_pos = 0

  return function()
    if pos > midi_buf:len() then
      return nil
    end

    local ppq_offset, flag, msg, next_pos = string.unpack("i4Bs4", midi_buf, pos)
    if not ppq_offset or not flag or not msg or not next_pos then
      return nil
    end

    ppq_pos = ppq_pos + ppq_offset
    local time = reaper.MIDI_GetProjTimeFromPPQPos(take, ppq_pos)

    pos = next_pos
    return time, flag, msg
  end
end

return ReaperUtils
