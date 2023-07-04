ALL_TESTS = true

require("test.integration_test")
require("test.mst_test")
require("test.unit_test")
OS = require("os")
local lu = require('lib.luaunit')

OS.exit(lu.LuaUnit.run())
