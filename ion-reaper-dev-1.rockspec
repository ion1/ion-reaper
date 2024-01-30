rockspec_format = "3.0"
package = "ion-reaper"
version = "dev-1"
description = {
  summary = "ion's Reaper stuff",
  homepage = "https://github.com/ion1/ion-reaper",
  license = "MIT",
}
test = {
  type = "busted",
  flags = { "src" },
}
dependencies = { "lua >= 5.1, < 5.5" }
test_dependencies = {
  "busted >= 2.2, < 2.3",
  "luacov >= 0.15, < 0.16",
}
