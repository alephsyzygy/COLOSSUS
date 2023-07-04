-- coord table: tables with coords as keys

require("common.utils.utils")
require("common.utils.objects")

---A CoordTable is a table of tables
---@class CoordTable : table<int, table<int, T>>
CoordTable = {}
-- Create a new CoordTable
---Create a new CoordTable
---@generic T
---@return CoordTable<T>
function CoordTable.new()
    return {}
end

-- return the value at coordinate (x,y)
-- x: int
-- y: int
-- returns nil if nothing at that coordinate
---return the value at coordinate (x,y)
---@generic T
---@param table CoordTable<T>
---@param x int
---@param y int
---@return T|nil
function CoordTable.get(table, x, y)
    local x_table = table[x]
    if x_table == nil then
        return nil
    end
    return x_table[y]
end

---set the value at coordinate (x,y)
---@generic T
---@param table CoordTable<T>
---@param x int
---@param y int
---@param value T
function CoordTable.set(table, x, y, value)
    if table[x] == nil then
        table[x] = {}
    end
    table[x][y] = value
end

-- PrimitiveType:
-- Table with keys {x=, y=} and value anything

-- used for iterating over x, y tables
-- lambda: takes two ints and a value, returns nothing
-- returns nothing
---comment
---@generic T
---@param table CoordTable<T>
---@param lambda any
function CoordTable.iterate(table, lambda)
    for x, x_table in pairs(table) do
        for y, value in pairs(x_table) do
            lambda(x, y, value)
        end
    end
end

---Create a CoordTable from an array of objects with x, y, value fields
---@generic T
---@param data {x: int, y: int, value: T}[]
---@return CoordTable<T>
function CoordTable.from_array(data)
    local out = CoordTable.new()
    for _, value in pairs(data) do
        CoordTable.set(out, value.x, value.y, value.value)
    end
    return out
end

local test = CoordTable.from_array { { x = 1, y = 2, value = "test" } }
assert(CoordTable.get(test, 2, 3) == nil)
CoordTable.set(test, 2, 3, "other")
assert(CoordTable.get(test, 2, 3) == "other")

---Return a list of keys of the coord table
---@generic T
---@param coord_table CoordTable<T>
---@return {x: int, y: int}[]
function CoordTable.keys(coord_table)
    local out = {}
    for x, x_table in pairs(coord_table) do
        for y, _ in pairs(x_table) do
            table.insert(out, { x = x, y = y })
        end
    end
    return out
end

assert(CoordTable.keys(test)[1].y == 2)

---Transpose a CoordTable, switching x and y coordinates
---@generic T
---@param coord_table CoordTable<T>
---@return CoordTable<T>
function CoordTable.transpose(coord_table)
    local output = CoordTable.new()
    CoordTable.iterate(coord_table, function(x, y, value)
        CoordTable.set(output, y, x, value)
    end)

    return output
end
