-- various transformations

require("common.factorio_objects.blueprint")
require("common.config.config")
require("common.schematic.diagram")
require("common.factorio_objects.entity")
require("common.config.game_data")
require("common.schematic.grid")
require("common.factorio_objects.item")
require("common.schematic.primitive")
require("common.factorio_objects.recipe")
require("common.factorio_objects.signals")
require("common.factory_components.tags")

require("common.utils.utils")
require("common.schematic.coord_table")

Transformations = {}

---flip all the elements in a primitivie vertically

function Transformations.flip_primitive_vertical(primitive)
    -- TODO conver this into a transform so don't need deepcopies
    local out = CoordTable.new()
    CoordTable.iterate(primitive, function(x, y, entity)
        local new_entity = entity
        if entity.data.direction == EntityDirection.UP then
            new_entity = ActionPair.new(entity.data:clone(), entity.action)
            new_entity.data.direction = EntityDirection.DOWN
        elseif entity.data.direction == EntityDirection.DOWN then
            new_entity = ActionPair.new(entity.data:clone(), entity.action)
            new_entity.data.direction = EntityDirection.UP
        end
        CoordTable.set(out, x, -y, new_entity)
    end)
    return out
end

---flip all the elements in a primitivie horizontally
---@generic T
---@param primitive CoordTable<T>
---@return CoordTable<T>
function Transformations.flip_primitive_horizontal(primitive)
    -- TODO conver this into a transform so don't need deepcopies
    local out = CoordTable.new()
    CoordTable.iterate(primitive, function(x, y, entity)
        local new_entity = entity
        if entity.data.direction == EntityDirection.LEFT then
            new_entity = ActionPair.new(entity.data:clone(), entity.action)
            new_entity.data.direction = EntityDirection.RIGHT
        elseif entity.data.direction == EntityDirection.RIGHT then
            new_entity = ActionPair.new(entity.data:clone(), entity.action)
            new_entity.data.direction = EntityDirection.LEFT
        end
        CoordTable.set(out, x, -y, new_entity)
    end)
    return out
end

local priority_types = { "input_priority", "output_priority" }

---swap the sides of a splitter
---@generic T
---@param primitive CoordTable<T>
---@param full_config FullConfig
---@return CoordTable<T>
function Transformations.swap_splitter_sides(primitive, full_config)
    local out = CoordTable.new()
    CoordTable.iterate(primitive, function(x, y, entity)
        if full_config.game_data.splitters[entity.data.name] == true then
            local new_entity = entity.data.clone()
            for _, priority_type in pairs(priority_types) do
                if new_entity.args[priority_type] then
                    new_entity.args[priority_type] = SplitterSide.switch(
                        new_entity.args[priority_type]
                    )
                end
            end
            CoordTable.set(out, x, y, ActionPair.new(entity, entity.action))
        else
            CoordTable.set(out, x, y, entity)
        end
    end)
    return out
end

---reverse all belts in a primitive.
---Can fail if there are multiple belts feeding into a single belt
---@generic T
---@param primitive CoordTable<T>
---@param full_config FullConfig
---@return CoordTable<T>
function Transformations.reverse_belts_in_primitive(primitive, full_config)
    -- entity: ActionPair of Entity, dirs: set of EntityDirection
    local working = CoordTable.new()
    CoordTable.iterate(primitive, function(x, y, entity)
        local new_entity = entity
        if full_config.game_data.reversible_items[entity.data.name] == true then
            new_entity = ActionPair.new(entity.data:clone(), entity.action)
        end
        CoordTable.set(working, x, y, { entity = new_entity, dirs = {} })
    end)

    -- for every entity, if it is reversible then follow its direction
    -- and mark that cell with the opposite direction
    CoordTable.iterate(working, function(x, y, working_data)
        local entity = working_data.entity
        if not (full_config.game_data.reversible_items[entity.data.name] == true and
                entity.data.args and entity.data.args.type ~= "input") then
            return
        end
        local next_coord = Follow_direction(entity.data.direction, { x = x, y = y })
        local followed_entity = CoordTable.get(working, next_coord.x, next_coord.y)
        if followed_entity then
            followed_entity.dirs[Reverse_direction(entity.data.direction)] = true
        end
        if full_config.game_data.splitters[entity.data.name] == true then
            -- find the other part of the splitter
            local extra_output
            if entity.data.direction == EntityDirection.UP or
                entity.data.direction == EntityDirection.DOWN then
                local next_coord = Follow_direction(entity.data.direction, { x = x + 1, y = y })
                extra_output = CoordTable.get(working, next_coord.x, next_coord.y)
            else
                local next_coord = Follow_direction(entity.data.direction, { x = x, y = y + 1 })
                extra_output = CoordTable.get(working, next_coord.x, next_coord.y)
            end
            if extra_output then
                extra_output.dirs[Reverse_direction(entity.data.direction)] = true
            end
        end
    end)

    -- now go through all reversible items and do the switch
    CoordTable.iterate(working, function(_, _, working_data)
        local entity = working_data.entity
        local dirs = working_data.dirs
        if full_config.game_data.reversible_items[entity.data.name] ~= true then
            return
        end
        if full_config.game_data.underground_belts[entity.data.name] == true then
            -- special handling for underground belts
            if entity.data.args.type == "input" then
                entity.data.args.type = "output"
            elseif entity.data.args.type == "output" then
                entity.data.args.type = "input"
            else
                error("Unknown underground type")
            end
            entity.data.direction = Reverse_direction(entity.data.direction)
            return
        end
        local count = Set.count(dirs)
        if count == 0 then
            entity.data.direction = Reverse_direction(entity.data.direction)
        elseif count > 1 then
            error("Cannot reverse: Too many directions feeding into one")
        else
            local direction, _ = next(dirs, nil)
            entity.data.direction = direction
        end
    end)

    -- now copy to output
    local out = CoordTable.new()
    CoordTable.iterate(working, function(x, y, working_data)
        CoordTable.set(out, x, y, working_data.entity)
    end)
    return out
end

---Create a transformation that sets the recipe of a machine
---@param recipe_info RecipeInfo
---@param full_config FullConfig
---@return function
function Transformations.set_assembling_machine_details(recipe_info, full_config)
    local function mapping(entity)
        local is_beacon = EntityTags["beacon-number"].get_tag(entity) or EntityTags.beacon.get_tag(entity)
        if is_beacon and recipe_info.beacon_name == nil then
            -- delete this entity, we are not using beacons
            local clone = entity:clone()
            EntityTags[DELETE_TAG].set_tag(clone, true)
            return clone
        end
        local is_machine = EntityTags.machine.get_tag(entity)
        if is_machine or is_beacon then
            local props = Copy(entity.args)
            if not recipe_info.custom_recipe and is_machine then
                -- don't replace recipes for custom recipes
                props.recipe = recipe_info.recipe.name
            end
            -- TODO this may fail for pseduo recipes due to allowed modules
            if recipe_info.beacon_name and is_beacon then
                local items = {}
                for _, module_count in pairs(recipe_info.beacon_modules) do
                    items[module_count.name] = module_count.count
                end
                props.items = items
                return Entity.new(recipe_info.beacon_name, entity.direction, entity.tags, props)
            else
                local items = {}
                for _, module_count in ipairs(recipe_info.modules) do
                    items[module_count.name] = module_count.count
                end
                props.items = items
                return Entity.new(recipe_info.machine_name, entity.direction, entity.tags, props)
            end
        end
        return entity
    end

    return mapping
end

---Create a transformation that sets the transport belt
---@param full_config FullConfig
---@return function
function Transformations.set_transport_belt(full_config)
    local belt = full_config.belt_item_name
    local splitter = full_config.splitter_item_name
    local underground = full_config.game_data:get_underground_for_belt(belt)

    local function belt_mapping(entity)
        if entity.name == "transport-belt" then
            return Entity.new(belt, entity.direction, entity.tags, entity.args)
        end
        if entity.name == "splitter" then
            return Entity.new(splitter, entity.direction, entity.tags, entity.args)
        end
        if entity.name == "underground-belt" then
            return Entity.new(underground, entity.direction, entity.tags, entity.args)
        end
        return entity
    end

    return belt_mapping
end

---Create a transformation that sets all inserters to the one chosen in the config object
---@param config Config
---@return function
function Transformations.set_inserter(config)
    local inserter = config.inserter
    local function inserter_mapping(entity)
        if entity.name == "inserter" then
            return Entity.new(inserter, entity.direction, entity.tags, entity.args)
        end
        return entity
    end
    return inserter_mapping
end

---Create a transformation that sets the pump condition
---@param item Item
---@return function
function Transformations.set_pump_condition(item)
    local function pump_mapping(entity)
        if entity.name == "pump" and
            entity.args and
            entity.args.control_behavior and
            entity.args.control_behavior.circuit_condition and
            entity.args.control_behavior.circuit_condition.first_signal then
            -- deepcopy so we don't change any other entity's args
            local args = Deepcopy(entity.args)

            -- change the first signal
            args.control_behavior.circuit_condition.first_signal = {
                type = item.item_type,
                name = item.name,
            }

            return Entity.new("pump", entity.direction, entity.tags, args)
        end

        return entity
    end

    return pump_mapping
end

---Create a transformation that sets the timescale
---@param timescale int
---@return function
function Transformations.set_timescale(timescale)
    local function timescale_mapping(entity)
        if EntityTags["clocked-reset"].get_tag(entity) then
            -- deepcopy so we don't change any other entity's args
            local args = Deepcopy(entity.args)

            -- change the signals
            args.control_behavior.decider_conditions.second_signal = nil
            args.control_behavior.decider_conditions.constant = timescale

            return Entity.new(entity.name, entity.direction, entity.tags, args)
        end

        return entity
    end

    return timescale_mapping
end

---Create a transformation that sets the start time
---@param start_time? int default 1
---@return function
function Transformations.set_start_time(start_time)
    local function start_time_mapping(entity)
        if EntityTags["clocked-start"].get_tag(entity) then
            -- deepcopy so we don't change any other entity's args
            local args = Deepcopy(entity.args)

            -- change the signals
            args.control_behavior.decider_conditions.second_signal = nil
            args.control_behavior.decider_conditions.constant = start_time or 1

            return Entity.new(entity.name, entity.direction, entity.tags, args)
        end

        return entity
    end

    return start_time_mapping
end

---Create a transformation that sets the fluid flow rates
---@param flowrates table<int, {name: string, flowrate: float}>
---@return function
function Transformations.set_fluid_flowrates(flowrates)
    local function fluid_flowrate_mapping(entity)
        if EntityTags["clocked-fluid"].get_tag(entity) then
            local index = SpecialSignal.to_number(entity.args.control_behavior.decider_conditions.first_signal.name)
            if not index then
                return entity
            end
            if flowrates[index] == nil then
                -- entity is not used so delete it
                return Entity.new(entity.name, entity.direction, { [DELETE_TAG] = true }, nil)
            end

            local args = Deepcopy(entity.args)

            -- change the signals
            args.control_behavior.decider_conditions.first_signal = {
                type = "fluid",
                name = flowrates[index].name,
            }
            args.control_behavior.decider_conditions.constant = math.ceil(flowrates[index].flowrate)

            return Entity.new(entity.name, entity.direction, entity.tags, args)
        end

        return entity
    end

    return fluid_flowrate_mapping
end

---Removed clocked entities
---@param config Config
---@return any
function Transformations.removed_clocked(config)
    local function remove_clocked_entity(entity)
        local output = entity
        if EntityTags.clocked.get_tag(entity) then
            output = entity:clone()
            EntityTags[DELETE_TAG].set_tag(output, true)
        elseif EntityTags["clocked-red-wire"].get_tag(entity) or EntityTags["unclocked-remove-red-wire"].get_tag(entity) then
            output = entity:clone()
            EntityTags["clocked-red-wire"].set_tag(output, nil)
            if output.args and output.args.connections and output.args.connections["1"] and output.args.connections["1"].red then
                output.args.connections["1"].red = nil
            end
        end
        return output
    end
    return remove_clocked_entity
end

---Create a transformation that transforms an entity
---@param full_config FullConfig
---@return function
function Transformations.transform_entity(full_config)
    ---entity transformation
    ---@param entity Entity
    ---@return Entity
    local function entity_mapping(entity)
        for _, config_data in pairs(Config.TRANSFORMATION_CONFIG_DATA) do
            if entity.name == config_data.default then
                local new_name = full_config[config_data.config_name]
                local new_entity = entity:clone()
                new_entity.tags = Deepcopy(entity.tags)
                new_entity.name = new_name
                return new_entity
            end
        end
        return entity
    end

    return entity_mapping
end

---Delete any entity with the belt-end tag
---@param entity Entity
---@return Entity
function Transformations.remove_belt_ends(entity)
    if entity.tags and EntityTags["belt-end"].get_tag(entity) then
        local new_entity = entity:clone()
        new_entity.tags = Deepcopy(entity.tags)
        EntityTags[DELETE_TAG].set_tag(new_entity, true)
        return new_entity
    end
    return entity
end

---Remove entities associated to unused ports
---@param port_names string[]
---@return function
function Transformations.remove_unused_port_entitites(port_names)
    local name_set = Set.from_array(port_names)
    return function(entity)
        if entity.tags then
            local entity_port_names = Set.from_array(EntityTags["port-name"].get_tag_array(entity))
            if not Set.empty(entity_port_names) and Set.empty(Set.intersection(entity_port_names, name_set)) then
                local new_entity = entity:clone()
                new_entity.tags = Deepcopy(entity.tags)
                EntityTags[DELETE_TAG].set_tag(new_entity, true)
                return new_entity
            end
        end
        return entity
    end
end

---Remove entities associated to unused ports
---@param item_outputs table<int, string>
---@param full_config FullConfig
---@return function
function Transformations.set_output_filters(item_outputs, full_config)
    return function(entity)
        if entity.tags then
            local port_num = EntityTags["splitter-right-filter"].get_tag(entity)
            local new_entity = entity:clone()
            new_entity.tags = Deepcopy(entity.tags)
            if port_num then
                if item_outputs[tonumber(port_num)] then
                    new_entity.args.filter = item_outputs[tonumber(port_num)]
                    new_entity.args.output_priority = "right"
                else
                    -- change this to a belt on the left part
                    new_entity.name = full_config.belt_item_name
                    local data = SplitterSide.get_individual_positions_delta(new_entity.direction,
                        SplitterSide.LEFT)
                    new_entity.tags.position_delta = { x = data.x, y = data.y }
                end
                return new_entity
            end
            port_num = EntityTags["splitter-left-filter"].get_tag(entity)
            if port_num then
                if item_outputs[tonumber(port_num)] then
                    new_entity.args.filter = item_outputs[tonumber(port_num)]
                    new_entity.args.output_priority = "left"
                else
                    -- change this to a belt on the right part
                    new_entity.name = full_config.belt_item_name
                    local data = SplitterSide.get_individual_positions_delta(new_entity.direction,
                        SplitterSide.RIGHT)
                    new_entity.tags.position_delta = { x = data.x, y = data.y }
                end
                return new_entity
            end
        end
        return entity
    end
end
