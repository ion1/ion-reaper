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

          assert.is.True(Misc.almost_equals(value, value + small_delta))
          assert.is.True(Misc.almost_equals(value, value - small_delta))

          assert.is.False(Misc.almost_equals(value, value + big_delta))
          assert.is.False(Misc.almost_equals(value, value - big_delta))
        end
      end
    end)
  end)

  describe("bytes", function()
    it("should return the byte values within a string", function()
      assert.are.equal("72 101 108 108 111 32 116 104 101 114 101", Misc.bytes("Hello there"))
    end)
  end)

  describe("adjacent_pairs", function()
    it("should not yield anything given an empty input", function()
      local actual = {}
      for value, previous_value in Misc.adjacent_pairs(function() end) do
        actual[#actual + 1] = { value, previous_value }
      end

      assert.are.same({}, actual)
    end)

    describe("should yield all adjacent pairs of values in the input", function()
      it("given a stateless iterator", function()
        local expected = {
          { {}, { 1, "a" } },
          { { 1, "a" }, { 2, "b" } },
          { { 2, "b" }, { 3, "c" } },
          { { 3, "c" }, { 4, "d" } },
          { { 4, "d" }, { 5, "e" } },
          { { 5, "e" }, {} },
        }

        local actual = {}
        for value, previous_value in Misc.adjacent_pairs(ipairs({ "a", "b", "c", "d", "e" })) do
          actual[#actual + 1] = { value, previous_value }
        end

        assert.are.same(expected, actual)
      end)

      it("given a stateful iterator", function()
        local function example_iterator(count)
          local i = 0
          return function()
            i = i + 1
            if i <= count then
              return i
            end
          end
        end

        local expected = {
          { {}, { 1 } },
          { { 1 }, { 2 } },
          { { 2 }, { 3 } },
          { { 3 }, { 4 } },
          { { 4 }, { 5 } },
          { { 5 }, {} },
        }

        local actual = {}
        for value, previous_value in Misc.adjacent_pairs(example_iterator(5)) do
          actual[#actual + 1] = { value, previous_value }
        end

        assert.are.same(expected, actual)
      end)
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
