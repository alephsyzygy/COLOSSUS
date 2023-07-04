---Represents a disjoint-set data structure

---A disjoint set entry
---@class DisjointSetEntry : BaseClass
---@field parent DisjointSetEntry
---@field rank int
---@field data any
DisjointSetEntry = InheritsFrom(nil)


---Create a new DisjointSetEntry
---@param data any
function DisjointSetEntry.new(data)
    local self = DisjointSetEntry:create()
    self.data = data
    self.parent = self
    self.rank = 0
    return self
end

---A disjoint set
---@class DisjointSet : BaseClass
---@field sets DisjointSetEntry[]
---@field count int
DisjointSet = InheritsFrom(nil)

---Create a new DisjointSet from a list
---@param data any[]
---@return DisjointSet
function DisjointSet.new(data)
    local self = DisjointSet:create()
    self.sets = {}
    for _, entry in ipairs(data) do
        table.insert(self.sets, DisjointSetEntry.new(entry))
    end
    self.count = #self.sets
    return self
end

---Get the DisjointSetEntry corresponding to the given index
---@param index int
---@return DisjointSetEntry
function DisjointSet:get(index)
    return self.sets[index]
end

---Find the root element of the given entry
---@param x DisjointSetEntry
---@return DisjointSetEntry
function DisjointSet:find(x)
    while x.parent ~= x do
        x.parent = x.parent.parent
        x = x.parent
    end
    return x
end

---Find the root element of the given entry, index version
---@param idx int
---@return DisjointSetEntry
function DisjointSet:find_idx(idx)
    return self:find(self.sets[idx])
end

---Union the two sets
---@param x DisjointSetEntry
---@param y DisjointSetEntry
function DisjointSet:union(x, y)
    -- find roots
    x = DisjointSet:find(x)
    y = DisjointSet:find(y)

    if x == y then
        -- they are already in the same set
        return
    end

    -- rename the variables so x's rank is at least as large as y
    if x.rank < y.rank then
        x, y = y, x
    end

    -- make x the new root
    y.parent = x

    -- increment the rank of x if necessary
    if x.rank == y.rank then
        x.rank = x.rank + 1
    end
end

---Union the two sets, index version
---@param idx_x int
---@param idx_y int
function DisjointSet:union_idx(idx_x, idx_y)
    return self:union(self.sets[idx_x], self.sets[idx_y])
end

TestDisjointSet = {}
function TestDisjointSet.test1()
    local lu = require('lib.luaunit')
    local data = { 1, 2, 3 }
    local disjointset = DisjointSet.new(data)
    disjointset:union_idx(1, 2)
    lu.assertEquals(disjointset:find_idx(1), disjointset:find_idx(1))
    lu.assertEquals(disjointset:find_idx(1), disjointset:find_idx(2))
    lu.assertNotEquals(disjointset:find_idx(1), disjointset:find_idx(3))
    lu.assertNotEquals(disjointset:find_idx(2), disjointset:find_idx(3))
    disjointset:union_idx(2, 3)
    lu.assertEquals(disjointset:find_idx(1), disjointset:find_idx(3))
end
