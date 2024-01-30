local Envelope = require("lib.envelope")

describe("Envelope", function()
  describe("add", function()
    it("should build an ordered table regardless of the insertion order", function()
      local env = Envelope:new()
      local data = {}
      for i = -100, 100, 1 do
        -- Using a slope which does not match the data to avoid coalescing.
        data[#data + 1] = { math.random(), { i, i * 2, -5 } }
      end

      local expected = {}

      for i, v in ipairs(data) do
        expected[i] = v[2]
      end

      table.sort(data, function(a, b)
        return a[1] < b[1]
      end)

      for i, v in ipairs(data) do
        env:add(table.unpack(v[2]))
      end

      assert.are.same(expected, env.table)
    end)
  end)
end)
