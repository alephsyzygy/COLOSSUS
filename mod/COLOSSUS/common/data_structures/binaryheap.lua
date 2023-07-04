require('common.utils.objects')

---@class HeapNode : BaseClass
---@field key int
---@field value any
HeapNode = InheritsFrom(nil)

---Create a new binary heap node
---@param key int|float
---@param value any
---@return HeapNode
function HeapNode.new(key, value)
	local self = HeapNode:create()
	self.value = value
	self.key = key
	return self
end

---@class BinaryHeap : BaseClass
---@field size int
---@field data any[]
BinaryHeap = InheritsFrom(nil)

---Create a new BinaryHeap
---@return BinaryHeap
function BinaryHeap.new()
	local self = BinaryHeap:create()
	self.data = {}
	self.size = 0
	return self
end

---Parent of the given index
---@param idx int
---@return integer
local function parent(idx)
	return math.floor(((idx - 1) - 1) / 2) + 1
end

---Left child of the given index
---@param idx int
---@return int
local function left(idx)
	return (idx - 1) * 2 + 2
end

---Right child of the given index
---@param idx int
---@return int
local function right(idx)
	return (idx - 1) * 2 + 2 + 1
end

---Shift the given index up in the heap
---@param idx int
function BinaryHeap:shift_up(idx)
	while (idx > 1 and self.data[parent(idx)].key > self.data[idx].key) do
		-- swap parent and current node
		self:swap(parent(idx), idx)
		idx = parent(idx)
	end
end

---Shift the index down in the heap
---@param idx int
function BinaryHeap:shift_down(idx)
	local max_idx = idx
	local left_child = left(idx)
	if (left_child <= self.size and self.data[left_child].key < self.data[max_idx].key) then
		max_idx = left_child
	end
	local rightChild = right(idx)
	if (rightChild <= self.size and self.data[rightChild].key < self.data[max_idx].key) then
		max_idx = rightChild
	end
	if idx ~= max_idx then
		self:swap(idx, max_idx)
		self:shift_down(max_idx)
	end
end

---Insert the given value into the heap
---@param key int|float
---@param value any
function BinaryHeap:insert(key, value)
	self.size = self.size + 1
	table.insert(self.data, HeapNode.new(key, value))
	self:shift_up(self.size)
end

---Extract the minimum element of the heap, removing it from the heap
---@return HeapNode
function BinaryHeap:extract_min()
	local out = self.data[1]
	self.data[1] = self.data[self.size]
	self.data[self.size] = nil
	self.size = self.size - 1
	self:shift_down(1)
	return out
end

---Get the minimum value of this heap
---@return HeapNode
function BinaryHeap:get_min()
	return self.data[1]
end

---Remove this index from the heap
---@param idx int
function BinaryHeap:remove(idx)
	self.data[idx] = self:get_min()
	self.data[idx].key = self.data[idx].key + 1
	self:shift_up(idx)
	self:extract_min()
end

---Swap two elements in the heap
---@param idx1 int
---@param idx2 int
function BinaryHeap:swap(idx1, idx2)
	local temp = self.data[idx1]
	self.data[idx1] = self.data[idx2]
	self.data[idx2] = temp
end

TestBinaryHeap = {}
function TestBinaryHeap.test1()
	local lu = require('lib.luaunit')
	lu.assertEquals(parent(2), 1)
	lu.assertEquals(parent(3), 1)
	lu.assertEquals(parent(4), 2)
	lu.assertEquals(parent(5), 2)
	lu.assertEquals(parent(6), 3)
	lu.assertEquals(left(1), 2)
	lu.assertEquals(right(1), 3)
	lu.assertEquals(left(2), 4)
	lu.assertEquals(right(2), 5)
	lu.assertEquals(left(3), 6)
	lu.assertEquals(right(3), 7)
end

function TestBinaryHeap.test2()
	local lu = require('lib.luaunit')
	local heap = BinaryHeap.new()
	heap:insert(45, "a")
	heap:insert(20, "b")
	heap:insert(14, "c")
	heap:insert(12, "d")
	heap:insert(31, "e")
	heap:insert(7, "f")
	heap:insert(11, "g")
	heap:insert(13, "h")
	heap:insert(7, "i")
	local max = heap:extract_min()
	local keys = {}
	while max ~= nil do
		table.insert(keys, max.key)
		max = heap:extract_min()
	end
	lu.assertEquals(keys, { 7, 7, 11, 12, 13, 14, 20, 31, 45 })
end
