local assert = require("luassert")
local say = require("say")

local Misc = require("lib.misc")

local function are_almostequal(_state, arguments)
  local expected, actual = table.unpack(arguments)
  return Misc.equals(expected, actual)
end

say:set_namespace("en")
say:set("assertion.are_almostequal.positive", "Expected to be almost equal to %s: %s")
say:set("assertion.are_almostequal.negative", "Expected not to be almost equal to %s: %s")
assert:register(
  "assertion",
  "are_almostequal",
  are_almostequal,
  "assertion.are_almostequal.positive",
  "assertion.are_almostequal.negative"
)
