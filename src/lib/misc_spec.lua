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
end)
