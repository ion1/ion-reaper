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
end)
