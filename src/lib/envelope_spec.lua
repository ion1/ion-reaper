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

    it("should coalesce redundant elements when new ones are being added", function()
      local env = Envelope:new()
      local data = {}
      for i = -100, 100, 1 do
        -- Using a slope which matches the data.
        data[#data + 1] = { math.random(), { i, i * 2, 2 } }
      end

      table.sort(data, function(a, b)
        return a[1] < b[1]
      end)

      for i, v in ipairs(data) do
        env:add(table.unpack(v[2]))
      end

      assert.are.same({ { -100, -200, 2 } }, env.table)
    end)

    it("should coalesce redundant elements when existing ones are being replaced", function()
      local env = Envelope:new()
      env:add(0, 20, 2)
      env:add(1, 22, -2)

      env:add(2, 100, 0)

      env:add(3, 20, -2)
      env:add(4, 22, 2)

      env:add(5, 100, 0)

      env:add(6, 20, 2)
      env:add(7, 22, -2)
      env:add(8, 24, 2)

      env:add(9, 100, 0)

      -- Replace the element at 1 with a redundant one relative to the previous one.
      env:add(1, 22, 2)

      -- Replace the element at 3 with a redundant one relative to the next one.
      env:add(3, 20, 2)

      -- Replace the element at 7 with a redundant one relative to both the previous
      -- and the next ones.
      env:add(7, 22, 2)

      assert.are.same({
        { 0, 20, 2 },
        { 2, 100, 0 },
        { 3, 20, 2 },
        { 5, 100, 0 },
        { 6, 20, 2 },
        { 9, 100, 0 },
      }, env.table)
    end)
  end)
end)
