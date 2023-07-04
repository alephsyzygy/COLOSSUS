---Algorithm to color an inteveral graph

---@alias interval {left:number, right:number, ignore:boolean|nil}
---@alias tagged_interval {left: number, right: number, tag: any}

---Take a list of intervals and routine a coloring for each interval, such that
---overlapping intervals have different colors.
---@param intervals interval[]
---@return int[]
function ColorIntervals(intervals)
    -- tag the intervals so we know where they came from
    local tagged_intervals = {}
    local idx = 1
    for _, value in ipairs(intervals) do
        if value.ignore == nil or value.ignore == false then
            table.insert(tagged_intervals, { left = value.left, right = value.right, tag = idx })
        end
        idx = idx + 1
    end

    -- first we sort by the left endpoints
    table.sort(tagged_intervals, function(x, y) return x.left < y.left end)

    -- interval to color
    local color_mapping = {}

    ---@type number[] for each color how much has been reserved so far
    local color_reserved = {}
    local next_color = 1
    local found_color = false

    -- then we take each interval and assign it to the smallest legal color
    for _, interval in ipairs(tagged_intervals) do
        found_color = false
        for idx, reserved in ipairs(color_reserved) do
            if reserved < interval.left then
                -- it fits here, so insert it
                found_color = true
                color_mapping[interval.tag] = idx
                color_reserved[idx] = interval.right
                break
            end
        end
        if not found_color then
            -- if we can't fit it then create a new color
            color_mapping[interval.tag] = next_color
            color_reserved[next_color] = interval.right
            next_color = next_color + 1
        end
    end
    return color_mapping
end

local function mk_int(a, b) return { left = a, right = b } end
local function array_to_intervals(array)
    local idx = 1
    local output = {}
    while idx < #array do
        table.insert(output, mk_int(array[idx], array[idx + 1]))
        idx = idx + 2
    end
    return output
end

TestInterval = {}
function TestInterval.test()
    local luaunit = require('lib.luaunit')
    local intervals = { mk_int(0, 5), mk_int(1, 2), mk_int(3, 4), mk_int(7, 9), mk_int(2, 11), mk_int(10, 11) }
    luaunit.assertEquals(ColorIntervals(intervals), { 1, 2, 2, 1, 3, 1 })
    intervals = array_to_intervals { 0, 5, 6, 7, 8, 12, 2, 10, 11, 13, 1, 3, 4, 9 }
    luaunit.assertEquals(ColorIntervals(intervals), { 1, 1, 1, 3, 2, 2, 2 })
end
