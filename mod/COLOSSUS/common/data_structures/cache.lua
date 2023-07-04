--- A table that is given a lookup function and caches its results
--- Can be used to dump all the data it was requested in case of errors

require("common.utils.utils")

---@alias Cache table
Cache = {}

---Create a Cache using the given lookup function
---@param lookup_fun fun(key: any): any
---@return Cache
function Cache.new(lookup_fun)
    local metatable = { __data = {} }
    metatable.cached_to_table = function(self)
        return getmetatable(self).__data
    end
    metatable.__index = function(t, key)
        if key == "cached_to_table" then
            return getmetatable(t).cached_to_table
        end
        local cached = getmetatable(t).__data[key]
        if cached ~= nil then
            return cached
        end
        local result = lookup_fun(key)
        getmetatable(t).__data[key] = result
        t[key] = result
        return result
    end

    local out = setmetatable({}, metatable)
    return out
end

TestCache = {}
function TestCache.test_cache()
    local lu = require('lib.luaunit')
    local hit_count = 0

    local test_cache = Cache.new(function(key)
        hit_count = hit_count + 1
        if key == "test" then
            return 0
        end
        if key == "one" then
            return 1
        end
    end)
    lu.assertEquals(test_cache.test, 0)
    lu.assertEquals(hit_count, 1)
    lu.assertEquals(test_cache.test, 0)
    lu.assertEquals(hit_count, 1)
    lu.assertEquals(test_cache.test, 0)
    lu.assertEquals(hit_count, 1)
    lu.assertIsNil(test_cache.other)
    lu.assertEquals(hit_count, 2)
    lu.assertIsNil(test_cache.other)
    lu.assertEquals(hit_count, 3)
    lu.assertEquals(test_cache.one, 1)
    lu.assertEquals(hit_count, 4)
    lu.assertEquals(test_cache.one, 1)
    lu.assertEquals(hit_count, 4)
    test_cache.one = 2
    lu.assertEquals(test_cache.one, 2)
    lu.assertEquals(hit_count, 4)

    -- this shows that if we update the table the original cached version is still there
    lu.assertEquals(test_cache:cached_to_table(), { test = 0, one = 1 })
    lu.assertEquals(test_cache, { test = 0, one = 2 })
end
