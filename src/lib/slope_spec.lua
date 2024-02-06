require("src.lib.luassert_almostequal")

local Slope = require("lib.slope")

describe("Slope", function()
  describe("extrapolate", function()
    it("computes an extrapolated value at a given timestamp", function()
      for _ = 1, 100 do
        local reference_time = math.random(-10, 10)
        local time = math.random(-10, 10)
        local slope = math.random(-10, 10)
        assert.are.equal(
          slope * time,
          Slope.extrapolate(reference_time, slope * reference_time, slope, time)
        )
      end
    end)
  end)

  describe("is_redundant", function()
    it("determines whether a time-value-slope element is redundant given a previous one", function()
      assert.is.True(Slope.is_redundant(-1, -2, 2, 1, 2, 2))
      assert.is.False(Slope.is_redundant(-1, -2, 2, 1, 2, -2))
      assert.is.False(Slope.is_redundant(-1, -2, 2, 1, 3, 2))
    end)
  end)

  describe("intersection_time", function()
    it("determines no intersection for parallel lines", function()
      for slope = -10, 10 do
        assert.is.Nil(Slope.intersection_time(-1, -2, slope, 1, 2, slope))
      end
    end)

    it("computes the intersection between non-parallel lines", function()
      assert.are.equal(0.5, Slope.intersection_time(-1, -2, 0, 1, 2, 8))
      assert.are.equal(10.5, Slope.intersection_time(10, 0, 1, 10, 1, -1))
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

        local time = Slope.intersection_time(a_time, a_value, a_slope, b_time, b_value, b_slope)

        local a_value_extrap = Slope.extrapolate(a_time, a_value, a_slope, time)
        local b_value_extrap = Slope.extrapolate(b_time, b_value, b_slope, time)

        assert.are.almostequal(a_value_extrap, b_value_extrap)
      end
    end)
  end)
end)
