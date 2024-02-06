require("src.lib.luassert_almostequal")

local Misc = require("lib.misc")

describe("Misc", function()
  describe("equals", function()
    it("calculates an approximate equality", function()
      for exponent = 0, 10 do
        for _, base_value in ipairs({ 1, -1 }) do
          local scale = 10 ^ exponent
          local value = base_value * scale
          local small_delta = 1e-7 * scale
          local big_delta = 1e-5 * scale

          assert.is.True(Misc.equals(value, value + small_delta))
          assert.is.True(Misc.equals(value, value - small_delta))

          assert.is.False(Misc.equals(value, value + big_delta))
          assert.is.False(Misc.equals(value, value - big_delta))
        end
      end
    end)
  end)

  describe("extrapolate", function()
    it("computes an extrapolated value at a given timestamp", function()
      for _ = 1, 100 do
        local reference_time = math.random(-10, 10)
        local time = math.random(-10, 10)
        local slope = math.random(-10, 10)
        assert.are.equal(
          slope * time,
          Misc.extrapolate(reference_time, slope * reference_time, slope, time)
        )
      end
    end)
  end)

  describe("is_redundant", function()
    it("determines whether a time-value-slope element is redundant given a previous one", function()
      assert.is.True(Misc.is_redundant(-1, -2, 2, 1, 2, 2))
      assert.is.False(Misc.is_redundant(-1, -2, 2, 1, 2, -2))
      assert.is.False(Misc.is_redundant(-1, -2, 2, 1, 3, 2))
    end)
  end)

  describe("intersection_time", function()
    it("determines no intersection for parallel lines", function()
      for slope = -10, 10 do
        assert.is.Nil(Misc.intersection_time(-1, -2, slope, 1, 2, slope))
      end
    end)

    it("computes the intersection between non-parallel lines", function()
      assert.are.equal(0.5, Misc.intersection_time(-1, -2, 0, 1, 2, 8))
      assert.are.equal(10.5, Misc.intersection_time(10, 0, 1, 10, 1, -1))
    end)

    it("agrees with extrapolate", function()
      for _ = 1, 100, 1 do
        local a_time = math.random(-10, 10)
        local b_time = math.random(-10, 10)
        local a_value = math.random(-10, 10)
        local b_value = math.random(-10, 10)
        local a_slope = math.random(-10, 10)
        local b_slope
        repeat
          b_slope = math.random(-10, 10)
        until math.abs(b_slope - a_slope) > 1e-3

        local time = Misc.intersection_time(a_time, a_value, a_slope, b_time, b_value, b_slope)

        local a_value_extrap = Misc.extrapolate(a_time, a_value, a_slope, time)
        local b_value_extrap = Misc.extrapolate(b_time, b_value, b_slope, time)

        assert.are.almostequal(a_value_extrap, b_value_extrap)
      end
    end)
  end)

  describe("bytes", function()
    it("should return the byte values within a string", function()
      assert.are.equal("72 101 108 108 111 32 116 104 101 114 101", Misc.bytes("Hello there"))
    end)
  end)

  describe("midi_pitch_string", function()
    it("should return a string corresponding to the given MIDI pitch", function()
      assert.are.equal("A0(+00)", Misc.midi_pitch_string(69 - 4 * 12))
      assert.are.equal("A4(+00)", Misc.midi_pitch_string(69))
      assert.are.equal("A8(+00)", Misc.midi_pitch_string(69 + 4 * 12))
      assert.are.equal("C5(+00)", Misc.midi_pitch_string(72))
      assert.are.equal("C5(+50)", Misc.midi_pitch_string(72.5))
      assert.are.equal("C#5(-49)", Misc.midi_pitch_string(72.51))
    end)
  end)

  local midi_pitch_frequency_examples = {
    { -3, 440 / 64 },
    { 69, 440 },
    { 129, 440 * 32 },
    { 72, 440 * 2 ^ (3 / 12) },
    { 72.5, 440 * 2 ^ (3.5 / 12) },
  }

  describe("midi_pitch_to_frequency", function()
    it("should return the correct frequency for the given MIDI pitch", function()
      for _, example in ipairs(midi_pitch_frequency_examples) do
        local pitch, frequency = table.unpack(example)
        assert.are.almostequal(frequency, Misc.midi_pitch_to_frequency(pitch))
      end
    end)

    it("should agree with frequency_to_midi_pitch", function()
      for _ = 1, 100 do
        local frequency = 20000 * math.random()
        local pitch = Misc.frequency_to_midi_pitch(frequency)
        assert.are.almostequal(frequency, Misc.midi_pitch_to_frequency(pitch))
      end
    end)
  end)

  describe("frequency_to_midi_pitch", function()
    it("should return the correct MIDI pitch for the given frequency", function()
      for _, example in ipairs(midi_pitch_frequency_examples) do
        local pitch, frequency = table.unpack(example)
        assert.are.almostequal(pitch, Misc.frequency_to_midi_pitch(frequency))
      end
    end)

    it("should agree with midi_pitch_to_frequency", function()
      for _ = 1, 100 do
        local pitch = 250 * math.random() - 50
        local frequency = Misc.midi_pitch_to_frequency(pitch)
        assert.are.almostequal(pitch, Misc.frequency_to_midi_pitch(frequency))
      end
    end)
  end)
end)
