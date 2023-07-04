---Dump anything to a string
---@param o any
---@return string
function Dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) == 'table' then
                k = 'Table:{ ' .. Dump(k) .. ' }'
            elseif type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. '[' .. k .. '] = ' .. Dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

---Count the number of entries in a table
---@param T? table
---@return int
function Table_count(T)
    if T == nil then return 0 end
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

---Shallow copy of a table
---@param t table
---@return table
function Copy(t)
    local out = {}
    for key, value in pairs(t) do
        out[key] = value
    end
    setmetatable(out, getmetatable(t))
    return out
end

---Deep copy of a table
---Does not deepcopy keys
---@param t? table
---@return table
function Deepcopy(t)
    if t == nil then return {} end
    if type(t) ~= "table" then
        return t
    end
    local out = {}
    for key, value in pairs(t) do
        out[key] = Deepcopy(value)
    end
    setmetatable(out, getmetatable(t))
    return out
end

local test_table = { z = { a = { b = 3 } } }
assert(Deepcopy(test_table) ~= test_table)

---Find the max of an array
---@param array int[]
---@return int
function Array_max(array)
    if #array == 0 then
        assert(false, "Array_max: 0 length array")
    end
    local max = array[1]
    for _, value in ipairs(array) do
        if value > max then
            max = value
        end
    end
    return max
end

---Find the min of an array
---@param array int[]
---@return int
function Array_min(array)
    if #array == 0 then
        assert(false, "Array_min: 0 length array")
    end
    local min = array[1]
    for _, value in ipairs(array) do
        if value < min then
            min = value
        end
    end
    return min
end

assert(Array_max({ 1, 2, 4 }) == 4)
assert(Array_min({ 1, 2, 4 }) == 1)

---Find the sum of an array
---@param array int[]
---@return int
function Array_sum(array)
    if #array == 0 then
        return 0
    end
    local sum = 0
    for _, value in ipairs(array) do
        sum = sum + value
    end
    return sum
end

assert(Array_sum { 1, 2, 3 } == 6)


---Filter an array
---@param array any[]
---@param filter function
---@return any[]
function Array_filter(array, filter)
    local output = {}
    for _, value in ipairs(array) do
        if filter(value) then
            table.insert(output, value)
        end
    end
    return output
end

-- Set namespace
---@class Set<T>: { [T]: boolean }
Set = {}

---form the union of two sets
---@generic T
---@param set1 Set<T>
---@param set2 Set<T>
---@return Set<T>
function Set.union(set1, set2)
    local out = {}
    for key, value in pairs(set1) do
        if value == true then
            out[key] = true
        end
    end
    for key, value in pairs(set2) do
        if value == true then
            out[key] = true
        end
    end
    return out
end

---form the intersection of two sets
---@generic T
---@param set1 Set<T>
---@param set2 Set<T>
---@return Set<T>
function Set.intersection(set1, set2)
    local out = {}
    for key, value in pairs(set1) do
        if value == true and set2[key] == true then
            out[key] = true
        end
    end
    return out
end

---Are the sets equal?  Returns false if not well formed
---@generic T
---@param set1 Set<T>
---@param set2 Set<T>
---@return boolean
function Set.equal(set1, set2)
    for key, value in pairs(set1) do
        if value == true then
            if set2[key] ~= true then
                return false
            end
        else
            return false
        end
    end
    for key, value in pairs(set2) do
        if value == true then
            if set1[key] ~= true then
                return false
            end
        else
            return false
        end
    end
    return true
end

---Count the elements in a set
---@generic T
---@param set Set<T>
---@return int
function Set.count(set)
    local count = 0
    for _, _ in pairs(set) do
        count = count + 1
    end
    return count
end

---Is a set empty
---@generic T
---@param set Set<T>
---@return boolean
function Set.empty(set)
    for _, _ in pairs(set) do
        return false
    end
    return true
end

---Convert an array to a set
---@generic T
---@param array T[]
---@return Set<T>
function Set.from_array(array)
    local out = {}
    for _, value in ipairs(array) do
        out[value] = true
    end
    return out
end

---Apply a mapping to a set
---@param func fun(x:any):any
---@param set? Set<any>
---@return Set<any>?
function Set.map(func, set)
    if set == nil then return set end
    local out = {}
    for key, _ in pairs(set) do
        local value = func(key)
        if value then
            out[value] = true
        end
    end
    return out
end

assert(Set.equal(Set.union({ a = true, b = true }, { b = true, c = true }), { a = true, b = true, c = true }))
assert(Set.equal(Set.intersection({ a = true, b = true }, { b = true, c = true }), { b = true }))
assert(not Set.empty({ a = true }))
assert(Set.empty({}))

function Pad_string(str, width)
    if str == nil then
        return string.rep(" ", width)
    end
    local out = string.sub(str, 1, width)
    if #out < width then
        out = out .. string.rep(" ", width - #out)
    end
    return out
end

assert(Pad_string("hello", 10) == "hello     ")
assert(Pad_string("hello", 1) == "h")

---Concatenate two arrays into a new one
---@generic T
---@param first T[]
---@param second T[]
---@return T[]
function Concat_arrays(first, second)
    local output = {}
    for _, entry in ipairs(first) do
        table.insert(output, entry)
    end
    for _, entry in ipairs(second) do
        table.insert(output, entry)
    end
    return output
end

assert(Concat_arrays({ 1, 2 }, { 3, 4 })[3] == 3)

---process a function over multiple tables
---@generic K
---@generic V
---@param func fun(x: K, y: V)
---@param ... table<K,V>[]
function Multi_pairs(func, ...)
    local data = table.pack(...)
    for i, table in pairs(data) do
        if i == "n" then
            break
        end
        for key, value in pairs(table) do
            func(key, value)
        end
    end
end

local test_out = ""
local test_fun = function(x, y)
    test_out = test_out .. y
end
print(Multi_pairs(test_fun, { 1, 2, 3 }, { 4, 5, 6 }))
assert(test_out == "123456")

---Is a table empty
---@param table table?
---@return boolean
function Table_empty(table)
    if table == nil then
        return true
    end
    for _, _ in pairs(table) do
        return false
    end
    return true
end

---Set the given path in a table to value
---@param data table
---@param path any[]
---@param value any
function Set_path_if_null(data, path, value)
    local current = data
    local next
    for idx = 1, #path - 1 do
        next = current[path[idx]]
        if next == nil then
            current[path[idx]] = {}
        end
        current = current[path[idx]]
    end
    if current[path[#path]] == nil then
        current[path[#path]] = value
    end
end

---Get the value in a table following the given path
---@param data? table
---@param path any[]
---@returns any?
function Get_path(data, path)
    if data == nil then
        return nil
    end
    local current = data
    local next
    for idx = 1, #path - 1 do
        next = current[path[idx]]
        if next == nil then
            return nil
        end
        current = current[path[idx]]
    end
    return current[path[#path]]
end

---Get the given path in a table, setting it to a default if necessary
---@param data table
---@param path any[]
---@param default any
function Get_path_default(data, path, default)
    local current = data
    local next
    for idx = 1, #path - 1 do
        next = current[path[idx]]
        if next == nil then
            current[path[idx]] = {}
        end
        current = current[path[idx]]
    end
    if current[path[#path]] == nil then
        current[path[#path]] = default
    end
    return current[path[#path]]
end

TestUtils = {}
function TestUtils.test_set_path()
    local lu = require('lib.luaunit')
    local test = {}
    Set_path_if_null(test, { "one", 1, "two", "three" }, "result")
    lu.assertEquals(test.one[1].two.three, "result")
end

function TestUtils.test_get_path()
    local lu = require('lib.luaunit')
    local test = { one = { two = { three = "success" } } }
    lu.assertEquals(Get_path(test, { "one", "two", "three" }), "success")
    lu.assertEquals(Get_path(test, { "one", "two", "other" }), nil)
    lu.assertEquals(Get_path(test, { "other", "two", "three" }), nil)
end

function TestUtils.test_get_path_default()
    local lu = require('lib.luaunit')
    local test = {}
    local path = { "one", 1, "two", "three" }
    lu.assertEquals(Get_path_default(test, path, {}), {})
    table.insert(Get_path_default(test, path, {}), "one")
    lu.assertEquals(Get_path_default(test, path, {}), { "one" })
    table.insert(Get_path_default(test, path, {}), "two")
    lu.assertEquals(Get_path_default(test, path, {}), { "one", "two" })
end

---Split a string into an array
---@param input string
---@param sep? string deafult ","
---@return string[]
function Split_string(input, sep)
    if input == nil then return {} end
    if sep == nil then
        sep = ","
    end
    local output = {}
    for str in string.gmatch(input, "([^" .. sep .. "]+)") do
        table.insert(output, str)
    end
    return output
end

function TestUtils.test_split()
    local lu = require('lib.luaunit')
    local test = "one,two,three"
    lu.assertEquals(Split_string(test, ","), { "one", "two", "three" })
end

---Get all keys from a table
---@param input? table<any,any>
---@return any[]
function Table_keys(input)
    local output = {}
    if input == nil then return output end
    for key, value in pairs(input) do
        table.insert(output, key)
    end

    return output
end

---Get all keys from a table in Set form
---@param input? table<any,any>
---@return Set<any>
function Table_keys_set(input)
    local output = {}
    if input == nil then return output end
    for key, value in pairs(input) do
        output[key] = true
    end

    return output
end

---Does the given string start with the prefix
---@param s string
---@param prefix string
---@return boolean
function String_startswith(s, prefix)
    return string.sub(s, 1, string.len(prefix)) == prefix
end
