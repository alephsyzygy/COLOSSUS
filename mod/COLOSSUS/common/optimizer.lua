--- Optimization functions

require("common.config.game_data")
require("common.factorio_objects.entity")
require("common.schematic.grid")
require("common.factory_components.tags")

require("common.schematic.coord_table")
require("common.utils.utils")

-- Optimization functions
-- WARNING: at this stage various entity and entity values may not be unique, they may be shared
-- ensure you clone entities or copy tags or deepcopy args
-- entity numbers have not been assigned yet, so some entities may have shared data
Optimizations = {}

-- if we see an underground belt of type key, then travel int tiles in
-- int direction.  If there is nothing blocking then replace all with
-- Entity str, matching direction
local function init(full_config)
    full_config.replacement_info = {}
    for entity_name, _ in pairs(full_config.game_data.transport_belts) do
        local entity = full_config.game_data.entities[entity_name]
        local related = entity.related_underground_belt
        if related then
            full_config.replacement_info[related] = {
                entity = entity_name,
                max_distance = full_config.game_data.entities[related].max_underground_distance
            }
        end
    end
end

---Optimize: Replace unnecessary underground belts with belts
---@param primitive CoordTable<Entity>
---@param full_config FullConfig
---@return CoordTable<Entity>
function Optimizations.optimize_underground_belts(primitive, full_config)
    if full_config.replacement_info == nil then
        init(full_config)
    end
    local replacement_count = 0
    local entities_placed = 0

    ---@type CoordTable<Entity>
    local out = CoordTable.new()

    CoordTable.iterate(primitive, function(x, y, entity)
        if CoordTable.get(out, x, y) ~= nil then
            -- we have already processed this entity
            return
        end

        -- lookup entity
        local entity_data = full_config.game_data.entities[entity.name]
        if entity_data == nil or
            entity_data.type ~= "underground-belt" or
            (entity_data.args and entity_data.args.type == "output") then
            -- special entity not covered by game, just return
            CoordTable.set(out, x, y, entity)
            return
        end

        -- now we have an underground belt
        local info = full_config.replacement_info[entity.name]
        local replacement_name, max_underground_distance = info.entity, info.max_distance

        -- if we have set a default belt item then just use that
        if full_config.belt_item_name ~= nil then
            replacement_name = full_config.belt_item_name
        end

        local direction = entity.direction
        ---@type int?
        local found_end
        local loc = { x = x, y = y }
        ---@type Entity?
        local next_entity
        for i = 1, max_underground_distance do
            loc = Follow_direction(direction, loc)
            next_entity = CoordTable.get(primitive, loc.x, loc.y)
            if next_entity ~= nil then
                if next_entity.name == entity.name and
                    next_entity.direction == direction and
                    next_entity.args and
                    next_entity.args.type == "output" then
                    found_end = i
                elseif EntityTags["delete"].get_tag(next_entity) then
                    -- continue
                else
                    break
                end
            end
        end

        if found_end == nil then
            -- not suitable so return entity and continue
            CoordTable.set(out, x, y, entity)
            return
        end

        -- otherwise replace all entries with belts
        replacement_count = replacement_count + 1
        loc = { x = x, y = y }
        for _ = 0, found_end do
            CoordTable.set(out, loc.x, loc.y, Entity.new(replacement_name, direction))
            entities_placed = entities_placed + 1
            loc = Follow_direction(direction, loc)
        end
    end)

    full_config.logger:info("Underground belt optimization: Remove " ..
        replacement_count .. " underground pairs, added " .. entities_placed .. " belts.")


    return out
end

local function ensure_tags_unique(primitive)
    local tags = {}
    local entities = {}

    CoordTable.iterate(primitive, function(x, y, entity)
        if tags[entity.tags] ~= nil then
            print(tags[entity.tags])
            error(Dump(entity))
        end
        tags[entity.tags] = true

        if entities[entity] ~= nil then
            print(entities[entity])
            error(Dump(entity))
        end
        entities[entity] = true
    end)
end

---Optimize: Remove unnecessary underground pipes
---@param primitive CoordTable<Entity>
---@param full_config FullConfig
---@return CoordTable<Entity>
function Optimizations.optimize_underground_pipes(primitive, full_config)
    --- the idea here is to find all underground belts, follow them for the max distance,
    --- and if you find multiple maches then remove the intermediate ones
    local entities_deleted = 0

    ---@type CoordTable<Entity>
    local out = CoordTable.new()

    CoordTable.iterate(primitive, function(x, y, entity)
        if CoordTable.get(out, x, y) ~= nil then
            -- we have already processed this entity
            return
        end
        if entity.tags and EntityTags[DELETE_TAG].get_tag(entity) == true then
            -- this has already been deleted
            return
        end

        -- lookup entity
        local entity_data = full_config.game_data.entities[entity.name]
        if entity_data == nil or
            entity_data.type ~= "pipe-to-ground" then
            -- special entity not covered by game, just return
            CoordTable.set(out, x, y, entity)
            return
        end

        -- now we have a pipe-to-ground
        local max_underground_distance = entity_data.max_underground_distance

        local direction = Reverse_direction(entity.direction)
        if direction == nil then error("Direction of pipe-to-ground was nil, this should not happend") end
        local loc = { x = x, y = y }
        -- print(string.format("Starting at loc %d, %d", x, y))
        ---@type Entity?
        local next_entity
        local max_i = 0
        local max_seen = 0
        for i = 1, max_underground_distance do
            loc = Follow_direction(direction, loc)
            next_entity = CoordTable.get(out, loc.x, loc.y)
            if next_entity == nil then
                next_entity = CoordTable.get(primitive, loc.x, loc.y)
            end
            if next_entity and next_entity.name == "pipe-to-ground" and next_entity.direction == direction and EntityTags[DELETE_TAG].get_tag(next_entity) ~= true then
                -- print(string.format("Found pipe-to-ground at loc %d, %d", loc.x, loc.y))
                max_i = i
                max_seen = max_seen + 1
                -- print(string.format("max_i %d max_seen %d", max_i, max_seen))
            end
        end

        max_seen = max_seen - 1
        loc = { x = x, y = y }
        for i = 1, max_underground_distance do
            if max_i > 0 and max_seen > 0 then
                loc = Follow_direction(direction, loc)
                next_entity = CoordTable.get(out, loc.x, loc.y)
                if next_entity == nil then
                    next_entity = CoordTable.get(primitive, loc.x, loc.y)
                end
                if next_entity and next_entity.name == "pipe-to-ground" and next_entity.direction == direction and EntityTags[DELETE_TAG].get_tag(next_entity) ~= true then
                    max_i = max_i - 1
                    max_seen = max_seen - 1
                    local next_loc = Follow_direction(direction, loc)
                    local next_next_entity = CoordTable.get(out, next_loc.x, next_loc.y)
                    if next_next_entity == nil then
                        next_next_entity = CoordTable.get(primitive, next_loc.x, next_loc.y)
                    end
                    if next_next_entity and
                        next_next_entity.name == "pipe-to-ground" and
                        next_next_entity.direction == entity.direction and
                        not (next_next_entity.tags and EntityTags[DELETE_TAG].get_tag(next_next_entity) == true) then
                        -- clone the objects, set their delete tags, and add to out
                        local entity1 = next_entity:clone()
                        entity1.tags = {}
                        EntityTags[DELETE_TAG].set_tag(entity1, true)
                        local entity2 = next_next_entity:clone()
                        entity2.tags = {}
                        EntityTags[DELETE_TAG].set_tag(entity2, true)
                        CoordTable.set(out, loc.x, loc.y, entity1)
                        CoordTable.set(out, next_loc.x, next_loc.y, entity2)
                        -- print(string.format("Deleting (%d,%d) and (%d,%d)", loc.x, loc.y, next_loc.x, next_loc.y))

                        entities_deleted = entities_deleted + 2
                    end
                end
            end
        end

        CoordTable.set(out, x, y, entity)
    end)

    full_config.logger:info("Underground belt optimization: Removed " .. entities_deleted .. " pipe-to-grounds.")

    return out
end
