-- primitive types

require("common.schematic.diagram")
require("common.factorio_objects.entity")
require("common.schematic.coord_table")
require("common.factory_components.tags")


---concatenate primitivies
---@generic T
---@param primitives CoordTable<T>[]
---@return CoordTable<T>
function Concat_primitives(primitives)
    local out = CoordTable.new()
    for _, primitive in ipairs(primitives) do
        CoordTable.iterate(primitive, function(x, y, value)
            if CoordTable.get(out, x, y) == nil then
                -- haven't seen before so set it
                CoordTable.set(out, x, y, value:run())
            end
        end)
    end
    return out
end

---concatenate primitivies, removing deleted items.  Keep entities named "delete"
---@generic T
---@param primitives CoordTable<T>[]
---@return CoordTable<T>
function Concat_primitives_with_delete(primitives)
    local out = CoordTable.new()
    local deleted = CoordTable.new()
    for _, primitive in ipairs(primitives) do
        CoordTable.iterate(primitive, function(x, y, value)
            if CoordTable.get(out, x, y) == nil and CoordTable.get(deleted, x, y) == nil then
                -- haven't seen before so set it
                local result = value:run()
                if EntityTags[DELETE_TAG].get_tag(result) ~= true or result.name == DELETE_TAG then
                    CoordTable.set(out, x, y, result)
                else
                    -- see if it has a parent and if that has been deleted, in which case we just ignore this
                    local parent = EntityTags.parent.get_tag(result)
                    if parent then
                        if CoordTable.get(deleted, parent.x, parent.y) then
                            -- parent already deleted, do nothing
                        else
                            local parent_entity = CoordTable.get(primitive, parent.x, parent.y)
                            if parent_entity and EntityTags[DELETE_TAG].get_tag(parent_entity) == true then
                                -- parent about to be deleted, do nothing
                            else
                                CoordTable.set(deleted, x, y, true)
                            end
                        end
                    else
                        CoordTable.set(deleted, x, y, true)
                    end
                end
            end
        end)
    end
    return out
end

---Convert a PrimitiveEntityType to a PrimitiveActionType
---@generic T
---@param primitive CoordTable<ActionPair>
---@return CoordTable<T>
function Primitives_to_actions(primitive)
    local out = CoordTable.new()
    CoordTable.iterate(primitive, function(x, y, value)
        CoordTable.set(out, x, y, ActionPair.new(value, nil))
    end)
    return out
end

---for large objects we need to generate delete entitites so
---nothing intersects with them
---@param name string
---@param x int
---@param y int
---@param direction EntityDirection
---@param size_data SizeData
---@return {x: int, y: int, parent_x: int, parent_y: int}[]
local function generate_delete_entities(name, x, y, direction, size_data)
    local out = {} -- array
    local size = size_data[name]
    local size_x, size_y = 1, 1
    if size then
        size_x, size_y = size.width, size.height
    end
    if direction == EntityDirection.LEFT or direction == EntityDirection.RIGHT then
        -- swap size data
        size_x, size_y = size_y, size_x
    end
    for i = 0, size_x - 1 do
        for j = 0, size_y - 1 do
            -- don't delete the (0,0) entry
            if not (i == 0 and j == 0) then
                table.insert(out, { x = x + i, y = y + j, parent_x = x, parent_y = y })
            end
        end
    end
    return out
end

function Set_delete_entities(coord_table, name, x, y, direction, size_data)
    for _, delete_coord in pairs(generate_delete_entities(name, x, y, direction, size_data)) do
        CoordTable.set(coord_table, delete_coord.x, delete_coord.y,
            ActionPair.new(
                Entity.new(DELETE_TAG, 0,
                    {
                        [DELETE_TAG] = true,
                        [EntityTags.parent.name] = { x = delete_coord.parent_x, y = delete_coord.parent_y }
                    }, nil), nil))
    end
end

local test_primitives = {
    CoordTable.from_array {
        { x = 1, y = 1, value = Action_string("A") }
    },
    CoordTable.from_array {
        { x = 1, y = 1, value = Action_string("B") }
    },
}
assert(CoordTable.get(Concat_primitives(test_primitives), 1, 1) == "A")
