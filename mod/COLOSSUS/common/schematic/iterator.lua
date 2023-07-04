--- experimental resumable iterator for coord tables

require("common.utils.utils")

local function create_iterator(data, initial_state)
    local xit, xf, xi = pairs(data)
    local x_prev = (initial_state and initial_state.x) or xi
    local x, xlist = xit(data, x_prev)
    local yit, yf, y = pairs(xlist)
    if initial_state then y = initial_state.y end

    local function resume()
        local function step(_, _)
            if x == nil then return nil end
            local value
            while value == nil do
                y, value = yit(xlist, y)
                if y then
                    return x, y, value
                end
                if y == nil then
                    x_prev = x
                    x, xlist = xit(data, x)
                    if x == nil then return nil end
                    yit, yf, y = pairs(xlist)
                end
            end
        end
        return step
    end

    local function state()
        return { x = x_prev, y = y }
    end

    return { resume = resume, state = state }
end

local data = { a = { 1, 2, 3 }, b = { 4, 5, 6 }, c = {}, { 9, 8, 7 }, { 6, 5, 4 }, { 3, 2, 1 } }

local iterator = create_iterator(data)
print(Dump(iterator))
local iterate = true
local i = 0
local state
while iterate do
    iterate = false
    local iterator = create_iterator(data, state)
    for x, y, value in iterator.resume() do
        i = i + 1
        iterate = true
        print(string.format("[%s, %s] %s", x, y, value))
        if i % 5 == 0 then
            print("breaking"); break
        end
        iterate = false
    end
    state = iterator.state()
end
