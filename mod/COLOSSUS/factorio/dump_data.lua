--- This file is used to dump factorio data to JSON files.
--- The output is in %appdata%/Factorio/script-output

---Inspect all entities with the given inspector
---@param entries table
---@param inspector function
---@return table
local function inspect_all(entries, inspector)
    local r = {}
    for k, v in pairs(entries) do r[k] = inspector(v) end
    return r
end

local function inspect_entity(node)
    local fluidbox = {}
    local related_underground_belt = nil
    local burner_prototype = nil
    for k, v in pairs(node.fluidbox_prototypes) do
        table.insert(fluidbox, {
            pipe_connections = v.pipe_connections,
            production_type = v.production_type,
            height = v.height,
            index = v.index
        })
    end
    if node.related_underground_belt ~= nil then
        related_underground_belt = node.related_underground_belt.name
    end
    if node.burner_prototype ~= nil then
        burner_prototype = { fuel_categories = Copy(node.burner_prototype.fuel_categories) }
    end

    return {
        name = node.name,
        tile_height = node.tile_height,
        tile_width = node.tile_width,
        type = node.type,
        crafting_categories = node.crafting_categories,
        crafting_speed = node.crafting_speed,
        energy_usage = node.energy_usage,
        module_inventory_size = node.module_inventory_size,
        max_circuit_wire_distance = node.max_circuit_wire_distance,
        max_energy_production = node.max_energy_production,
        is_building = node.is_building,
        max_energy_usage = node.max_energy_usage,
        max_wire_distance = node.max_wire_distance,
        supports_direction = node.supports_direction,
        valid = node.valid,
        fluid_capacity = node.fluid_capacity,
        max_underground_distance = node.max_underground_distance,
        belt_speed = node.belt_speed,
        related_underground_belt = related_underground_belt,
        fluidbox_prototypes = fluidbox,
        ingredient_count = node.ingredient_count,
        burner_prototype = burner_prototype,
        filter_count = node.filter_count,
        logistic_mode = node.logistic_mode,
        logistic_radius = node.logistic_radius,
        construction_radius = node.construction_radius,
    }
end


local function inspect_recipe(node)
    return {
        name = node.name,
        category = node.category,
        products = node.products,
        ingredients = node.ingredients,
        hidden = node.hidden,
        energy = node.energy,
        order = node.order
    }
end


local function inspect_tile(node)
    local items = {}
    if node.items_to_place_this ~= nil then
        for k, v in pairs(node.items_to_place_this) do
            table.insert(items, { name = v.name, count = v.count })
        end
    end
    local next_direction
    if node.next_direction ~= nil then
        next_direction = node.next_direction.name
    end

    return {
        name = node.name,
        can_be_part_of_blueprint = node.can_be_part_of_blueprint,
        check_collision_with_entities = node.check_collision_with_entities,
        items_to_place_this = items,
        vehicle_friction_modifier = node.vehicle_friction_modifier,
        walking_speed_modifier = node.walking_speed_modifier,
        next_direction = next_direction
    }
end


local function inspect_item(node)
    local consumption = 0.0
    local speed = 0.0
    local productivity = 0.0
    local pollution = 0.0
    local place_as_tile_result
    if node.place_as_tile_result ~= nil then
        place_as_tile_result = {}
        for key, value in pairs(node.place_as_tile_result) do
            place_as_tile_result[key] = value
        end
        place_as_tile_result.result = node.place_as_tile_result.result.name
    end
    if node.module_effects ~= nil then
        if node.module_effects.consumption ~= nil then
            consumption = node.module_effects.consumption.bonus
        end
        if node.module_effects.speed ~= nil then
            speed = node.module_effects.speed.bonus
        end
        if node.module_effects.productivity ~= nil then
            productivity = node.module_effects.productivity.bonus
        end
        if node.module_effects.pollution ~= nil then
            pollution = node.module_effects.pollution.bonus
        end
    end

    return {
        name = node.name,
        category = node.category,
        type = node.type,
        consumption = consumption,
        speed = speed,
        productivity = productivity,
        pollution = pollution,
        place_as_tile_result = place_as_tile_result,
        fuel_category = node.fuel_category,
        fuel_value = node.fuel_value,
        stack_size = node.stack_size,
    }
end

local function inspect_fluid(node)
    return {
        name = node.name,
        default_temperature = node.default_temperature,
        max_temperature = node.max_temperature,
        fuel_value = node.fuel_value,
        gas_temperature = node.gas_temperature,
        hidden = node.hidden,
    }
end

local function write_json(filename, data)
    game.write_file(filename, game.table_to_json(data))
end

---Extract data into a usable format for the rest of the mod
---@return {entities: table, recipes: table, tiles: table, items: table, fluids: table}
function Extract_data()
    local data = {
        entities = inspect_all(game.entity_prototypes, inspect_entity),
        recipes = inspect_all(game.recipe_prototypes, inspect_recipe),
        tiles = inspect_all(game.tile_prototypes, inspect_tile),
        items = inspect_all(game.item_prototypes, inspect_item),
        fluids = inspect_all(game.fluid_prototypes, inspect_fluid),
    }
    return data
end

local function create_lookup(data, filter_fun, inspector)
    return {
        lookup = function(key)
            local value = data[key]
            if value == nil then
                -- not an in-game item so return nil
                return nil
            end
            return inspector(value)
        end,
        type_filter = function(type_name)
            local out = {}
            for _, value in pairs(filter_fun { {
                filter = "type",
                type = type_name
            } }) do
                out[value.name] = true
            end
            return out
        end,
        item_filter = function(item_name)
            local out = {}
            for _, value in pairs(filter_fun {
                { filter = "has-ingredient-item", elem_filters = { { filter = "name", name = item_name } } },
                { filter = "has-product-item",    elem_filters = { { filter = "name", name = item_name } } } }) do
                out[value.name] = true
            end
            return out
        end,
        all_data = function() return data end
    }
end

---More targetted data
function Game_data_lookups()
    return {
        entities = create_lookup(game.entity_prototypes, game.get_filtered_entity_prototypes, inspect_entity),
        recipes = create_lookup(game.recipe_prototypes, game.get_filtered_recipe_prototypes, inspect_recipe),
        tiles = create_lookup(game.tile_prototypes, game.get_filtered_tile_prototypes, inspect_tile),
        items = create_lookup(game.item_prototypes, game.get_filtered_item_prototypes, inspect_item),
        fluids = create_lookup(game.fluid_prototypes, game.get_filtered_fluid_prototypes, inspect_fluid),
    }
end

---Write data out to a file in the scripts output folder
---@param player_index int
function Dump_data(player_index)
    local data = Extract_data()
    write_json("entities.json", data.entities)
    write_json("recipes.json", data.recipes)
    write_json("tiles.json", data.tiles)
    write_json("items.json", data.items)
    write_json("fluids.json", data.fluids)
end
