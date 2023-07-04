--- run all unit tests

require('common.data_structures.tree')
require('common.data_structures.cache')
require('common.data_structures.quadtree')
require('common.data_structures.disjointset')
require('common.data_structures.graph')
require('common.data_structures.binaryheap')
require('common.data_structures.interval_graph')

require("common.utils.utils")

require('test.mst_test')

OS = require("os")

local luaunit = require('lib.luaunit')

---@diagnostic disable-next-line: undefined-field
if _G.ALL_TESTS == nil then
    OS.exit(luaunit.LuaUnit.run())
end
