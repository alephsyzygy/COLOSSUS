--- trees

require("common.utils.objects")
require("common.utils.utils")

---@class Tree : BaseClass
Tree = InheritsFrom(nil)

---Recurse this tree
---@param node_fun? fun(any, any): any
---@param leaf_fun? fun(any): any
---@returns any
function Tree:recurse(node_fun, leaf_fun)
    error("This is an abstract method")
end

---@class Leaf : Tree
---@field data any
Leaf = InheritsFrom(Tree)


---Create a new BLeaf
---@param data any at this leaf
---@return Leaf
function Leaf.new(data)
    local self = Leaf:create()
    self.data = data
    return self
end

---Recurse this tree
---@param node_fun? fun(any, any): any
---@param leaf_fun? fun(any): any
---@returns any
function Leaf:recurse(node_fun, leaf_fun)
    if leaf_fun == nil then
        return nil
    end
    return leaf_fun(self.data)
end

---@class Node : Tree
---@field first Tree
---@field second Tree
Node = InheritsFrom(Tree)

---Create a new Node
---@param first any Tree
---@param second any Tree
---@return Node
function Node.new(first, second)
    local self = Node:create()
    self.first = first
    self.second = second
    return self
end

---Recurse this tree
---@param node_fun? fun(any, any): any
---@param leaf_fun? fun(any): any
---@returns any
function Node:recurse(node_fun, leaf_fun)
    local x = self.first:recurse(node_fun, leaf_fun)
    local y = self.second:recurse(node_fun, leaf_fun)
    if node_fun == nil then
        return nil
    end
    return node_fun(x, y)
end

TestTree = {}
function TestTree.test_recurse()
    local luaunit = require('lib.luaunit')
    local output = {}
    local data = Node.new(Node.new(Leaf.new { 1, 2, 3 }, Leaf.new { 4, 5, 6 }),
        Node.new(Leaf.new { 7, 8, 9 }, Node.new(Leaf.new { 10 }, Leaf.new { 99 })))
    data:recurse(nil, function(x) for _, v in ipairs(x) do table.insert(output, v) end end)
    luaunit.assertEquals(output, { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 99 })
end
