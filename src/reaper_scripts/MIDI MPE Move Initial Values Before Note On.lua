local MIDIMPEInitialValues = require("lib.midi_mpe_initial_values")
local Misc = require("lib.misc")
local ReaperUtils = require("lib.reaper_utils")

local MIDIMPEMoveInitialValueAfterNoteOn = {}
MIDIMPEMoveInitialValueAfterNoteOn.__index = MIDIMPEMoveInitialValueAfterNoteOn

function MIDIMPEMoveInitialValueAfterNoteOn.new()
  local self = setmetatable({}, MIDIMPEMoveInitialValueAfterNoteOn)
  return self
end

function MIDIMPEMoveInitialValueAfterNoteOn:process_selected()
  local hwnd = reaper.MIDIEditor_GetActive()
  if not hwnd then
    error("MIDIEditor_GetActive failed")
  end

  local take = reaper.MIDIEditor_GetTake(hwnd)
  if not take then
    error("MIDIEditor_GetTake failed")
  end

  MIDIMPEInitialValues.process_take(take, false)
end

local function main()
  reaper.Undo_BeginBlock2(0)
  MIDIMPEMoveInitialValueAfterNoteOn.new():process_selected()
  reaper.Undo_EndBlock2(0, "MIDI MPE Move Intial Value After Note On", -1)
end

main()
