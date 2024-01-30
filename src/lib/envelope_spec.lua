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

  describe("merge", function()
    it("should add elements to an empty envelope verbatim", function()
      local env = Envelope:new()

      local elements = {
        { 0, 100, 0 },
        { 1, 100, -10 },
        { 2, 90, 0 },
        { 5, 90, 10 },
        { 6, 100, 0 },
      }

      env:merge(elements)

      assert.are.same(elements, env.table)
    end)

    it("should combine two envelopes", function()
      local env = Envelope:new()

      env:merge({
        { 0, 100, 0 },
        { 1, 100, -10 },
        { 2, 90, 0 },
        { 4, 90, 10 },
        { 5, 100, 0 },
        { 6, 100, -10 },
        { 8, 80, 0 },
        { 9, 80, 10 },
        { 11, 100, 0 },
      })

      env:merge({
        { 1.5, 100, 0 },
        { 2.5, 100, -10 },
        { 4.5, 80, 0 },
        { 6, 80, 10 },
        { 8, 100, 0 },
      })

      assert.are.same({
        { 0, 100, 0 },
        { 1, 100, -10 },
        { 2, 90, 0 },
        { 3.5, 90, -10 },
        { 4.5, 80, 0 },
        { 6, 80, 10 },
        { 7, 90, -10 },
        { 8, 80, 0 },
        { 9, 80, 10 },
        { 11, 100, 0 },
      }, env.table)
    end)

    describe("given a ceiling value and the final element of the parameter matching it", function()
      local base = {
        { 0, 100, -10 },
        { 1, 90, 10 },
        { 2, 100, 0 },
        { 3, 100, 10 },
        { 4, 110, -10 },
        { 6, 90, 0 },
      }

      local patch = {
        { 0, 90, 10 },
        { 1, 100, 0 },
      }

      it("should not stop processing if the ceiling parameter is not given", function()
        local env = Envelope:new()
        env:merge(base)
        env:merge(patch)

        assert.are.same({
          { 0, 90, 10 },
          { 0.5, 95, -10 },
          { 1, 90, 10 },
          { 2, 100, 0 },
          { 5, 100, -10 },
          { 6, 90, 0 },
        }, env.table)
      end)

      it("should stop processing if the ceiling parameter is given", function()
        local env = Envelope:new()
        env:merge(base)
        env:merge(patch, { ceiling = 100 })

        assert.are.same({
          { 0, 90, 10 },
          { 0.5, 95, -10 },
          { 1, 90, 10 },
          { 2, 100, 0 },
          { 3, 100, 10 },
          { 4, 110, -10 },
          { 6, 90, 0 },
        }, env.table)
      end)
    end)
  end)
end)
