-- grid routines

require("common.utils.utils")
require("common.factorio_objects.entity")
require("common.config.game_data")

---Convert from Factorio coordinates to internal coordinates
---@param name string
---@param x float
---@param y float
---@param direction EntityDirection
---@param size_data SizeData
---@return {x : int, y : int}
function Fix_coord(name, x, y, direction, size_data)
    local size_data = size_data[name]
    local size_x = 1
    local size_y = 1
    if size_data ~= nil then
        size_x = size_data.width
        size_y = size_data.height
    end
    if direction == EntityDirection.LEFT or direction == EntityDirection.RIGHT then
        size_x, size_y = size_y, size_x
    end
    return { x = math.floor(x - size_x / 2), y = math.floor(y - size_y / 2) }
end

---Convert from internal coordinates to Factorio coordinates
---@param name string
---@param x int
---@param y int
---@param direction EntityDirection
---@param all_size_data SizeData
---@return {x : float, y :float}
function Fix_coord_inverse(name, x, y, direction, all_size_data)
    local size_data = all_size_data[name]
    local size_x = 1
    local size_y = 1
    if size_data ~= nil then
        size_x = size_data.width
        size_y = size_data.height
    end
    if direction == EntityDirection.LEFT or direction == EntityDirection.RIGHT then
        size_x, size_y = size_y, size_x
    end
    return { x = x + size_x / 2, y = y + size_y / 2 }
end

-- local test_coords = Fix_coord("splitter", 1, 0.5, EntityDirection.UP)
-- assert(test_coords.x == 0 and test_coords.y == 0)
-- test_coords = Fix_coord_inverse("splitter", test_coords.x, test_coords.y, EntityDirection.UP)
-- assert(test_coords.x == 1 and test_coords.y == 0.5)

---Reverse a direction
---@param dir EntityDirection
---@return EntityDirection
function Reverse_direction(dir)
    if dir == EntityDirection.UP then
        return EntityDirection.DOWN
    elseif dir == EntityDirection.DOWN then
        return EntityDirection.UP
    elseif dir == EntityDirection.LEFT then
        return EntityDirection.RIGHT
    elseif dir == EntityDirection.RIGHT then
        return EntityDirection.LEFT
    else
        error("Reverse_direction: Not an EntityDirection")
    end
end

---follow a direction
---@param dir EntityDirection
---@param pos {x : int, y : int}
---@return {x : int, y : int}
function Follow_direction(dir, pos)
    local x = pos.x
    local y = pos.y
    local result = { x = x, y = y }
    if dir == EntityDirection.UP then
        result.y = y - 1
    elseif dir == EntityDirection.DOWN then
        result.y = y + 1
    elseif dir == EntityDirection.LEFT then
        result.x = x - 1
    elseif dir == EntityDirection.RIGHT then
        result.x = x + 1
    else
        assert(false, "Follow_direction: dir is not an EntityDirection")
        -- return nil
    end
    return result
end

-- assert(Follow_direction(EntityDirection.RIGHT, { x = 3, y = 4 }).x == 4)
