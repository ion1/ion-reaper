local Envelope = require("lib.envelope")
local Misc = require("lib.misc")
local ReaperUtils = require("lib.reaper_utils")
local Slope = require("lib.slope")

local MIDIToFilterEnvelope = {}
MIDIToFilterEnvelope.__index = MIDIToFilterEnvelope

function MIDIToFilterEnvelope.new()
  local self = setmetatable({}, MIDIToFilterEnvelope)

  self.min_freq = 20
  self.max_freq = 20000
  self.linear = true
  self.interpolated_points_per_semitone = 1

  self.pitch_slope = 2
  self.maximum_slope_length = 3
  self.pitch_headroom_semitones = 5
  self.pitch_headroom_hz = 30
  self.spread_notes = 0.5

  self.max_pitch = self:point_value_to_midi_pitch(1)

  return self
end

function MIDIToFilterEnvelope:process_selected(project)
  local track_env = reaper.GetSelectedTrackEnvelope(0)
  if not track_env then
    error("No track envelope selected")
  end

  for media_item in ReaperUtils.selected_media_item_iterator(0) do
    self:process_media_item(track_env, media_item)
  end
end

function MIDIToFilterEnvelope:process_media_item(track_env, media_item)
  for segment in ReaperUtils.lowest_note_segment_iterator(media_item) do
    local envelope = Envelope.new()

    for _, note in ipairs(segment.notes) do
      local pitch_with_hr_semitones = note.pitch - self.pitch_headroom_semitones
      local pitch_with_hr_hz = Misc.frequency_to_midi_pitch(
        Misc.midi_pitch_to_frequency(note.pitch) - self.pitch_headroom_hz
      )
      local pitch = math.min(pitch_with_hr_semitones, pitch_with_hr_hz)

      local start_time = note.start_time - self.spread_notes
      local end_time = note.end_time + self.spread_notes

      -- TODO: unit test
      local incoming_edge_start_time =
        Slope.intersection_time(0, self.max_pitch, 0, start_time, pitch, -self.pitch_slope)

      local outgoing_edge_end_time =
        Slope.intersection_time(0, self.max_pitch, 0, end_time, pitch, self.pitch_slope)

      envelope:merge_points({
        { incoming_edge_start_time, self.max_pitch },
        { start_time, pitch },
        { end_time, pitch },
        { outgoing_edge_end_time, self.max_pitch },
      }, { ceiling = self.max_pitch })
    end

    -- Limit the start and the end of the segment envelope to the halfway point between
    -- the segments.
    local start_time_cap = segment.previous_segment_end_time
      and (segment.previous_segment_end_time + segment.start_time) / 2.0
    local end_time_cap = segment.next_segment_start_time
      and (segment.end_time + segment.next_segment_start_time) / 2.0

    self:construct_automation_item(track_env, start_time_cap, end_time_cap, envelope)
  end
end

function MIDIToFilterEnvelope:construct_automation_item(
  track_env,
  start_time_cap,
  end_time_cap,
  envelope
)
  if envelope.last_ix == 0 then
    error("Empty envelope")
  end

  local first_elem = envelope:lookup(1)
  local last_elem = envelope:lookup(envelope.last_ix)

  local item_pos = math.max(first_elem.time, 0)
  if start_time_cap then
    item_pos = math.max(start_time_cap, item_pos)
  end
  local item_start_offset = item_pos - first_elem.time
  local item_length = last_elem.time - first_elem.time
  local item_visible_end = last_elem.time
  if end_time_cap then
    item_visible_end = math.min(end_time_cap, item_visible_end)
  end
  local item_visible_length = item_visible_end - item_pos

  local auto_item = reaper.InsertAutomationItem(track_env, -1, item_pos, item_length)
  reaper.DeleteEnvelopePointRangeEx(
    track_env,
    auto_item,
    item_pos - 1.0,
    item_pos + item_length + 1.0
  )
  reaper.GetSetAutomationItemInfo(track_env, auto_item, "D_STARTOFFS", item_start_offset, true)
  reaper.GetSetAutomationItemInfo(track_env, auto_item, "D_LENGTH", item_visible_length, true)

  local function insert_point(time, value)
    reaper.InsertEnvelopePointEx(track_env, auto_item | 0x10000000, time, value, 0, 0, false, false)
  end

  local prev_time = nil
  local prev_pitch = nil
  for time, pitch, _slope, _length in envelope:elements() do
    if self.linear and prev_time and prev_pitch and pitch ~= prev_pitch then
      -- Add interpolated points since we can't add an exponential curve.
      local num_points =
        math.ceil(self.interpolated_points_per_semitone * math.abs(pitch - prev_pitch))

      -- Skip 0 (the previous point has already been added) and num_points - 1 (the
      -- current point will be added after the loop).
      for i = 1, num_points - 2 do
        local interp_pos = i / (num_points - 1)
        local interp_time = prev_time + (time - prev_time) * interp_pos
        local interp_pitch = prev_pitch + (pitch - prev_pitch) * interp_pos

        insert_point(interp_time, self:midi_pitch_to_point_value(interp_pitch))
      end
    end

    insert_point(time, self:midi_pitch_to_point_value(pitch))

    prev_time = time
    prev_pitch = pitch
  end
  reaper.Envelope_SortPointsEx(track_env, auto_item)
end

function MIDIToFilterEnvelope:midi_pitch_to_point_value(midi_pitch)
  -- TODO: self.linear
  local freq = Misc.midi_pitch_to_frequency(midi_pitch)
  local point_value = (freq - self.min_freq) / (self.max_freq - self.min_freq)
  Misc.debug(
    "MIDIPitchToPointValue: %d %s -> %.2f %.2f\n",
    midi_pitch,
    Misc.midi_pitch_string(midi_pitch),
    freq,
    point_value
  )
  return point_value
end

-- Returns a number which may not be an integer and may be outside the MIDI range.
function MIDIToFilterEnvelope:point_value_to_midi_pitch(point_value)
  -- TODO: self.linear
  local freq = point_value * (self.max_freq - self.min_freq) + self.min_freq
  local midi_pitch = Misc.frequency_to_midi_pitch(freq)
  Misc.debug(
    "PointValueToMIDIPitch: %.2f -> %.2f %s\n",
    point_value,
    midi_pitch,
    Misc.midi_pitch_string(midi_pitch)
  )
  return midi_pitch
end

local function main()
  reaper.Undo_BeginBlock2(0)
  MIDIToFilterEnvelope.new():process_selected(0)
  reaper.Undo_EndBlock2(0, "MIDI To Filter Envelope", -1)
end

main()
