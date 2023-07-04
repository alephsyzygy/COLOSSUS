-- represents data from the game

-- this will either be extracted from the game itself, or from json files

require("common.utils.utils")
require("common.factorio_objects.recipe")
require("common.utils.objects")

require("common.data_structures.cache")

---SplitterSide: sides of a splitter
---@enum SplitterSide
SplitterSide = {
    LEFT = "left",
    RIGHT = "right"
}

---Switch the sides of a SplitterSide
---@param splitter SplitterSide
---@return SplitterSide
function SplitterSide.switch(splitter)
    if splitter == SplitterSide.LEFT then
        return SplitterSide.RIGHT
    end
    return SplitterSide.LEFT
end

local splitter_position_data = {
    [EntityDirection.UP] = { [SplitterSide.LEFT] = { x = 0, y = 0 }, [SplitterSide.RIGHT] = { x = 1, y = 0 }, },
    [EntityDirection.DOWN] = { [SplitterSide.LEFT] = { x = 1, y = 0 }, [SplitterSide.RIGHT] = { x = 0, y = 0 }, },
    [EntityDirection.LEFT] = { [SplitterSide.LEFT] = { x = 0, y = 1 }, [SplitterSide.RIGHT] = { x = 0, y = 0 }, },
    [EntityDirection.RIGHT] = { [SplitterSide.LEFT] = { x = 0, y = 0 }, [SplitterSide.RIGHT] = { x = 0, y = 1 }, },
}

---Given a position x and y and a direction, return the x and y of the left or right side
---@param direction? EntityDirection
---@param side SplitterSide
---@returns {x: int, y: int}
function SplitterSide.get_individual_positions_delta(direction, side)
    if direction == nil then direction = 0 end
    return splitter_position_data[direction][side]
end

---Type of fluidbox data
---@alias Fluidbox {type: string, x: int, y: int, index: int}

---@alias SizeData table<string, {width: int, height: int}>

---@class GameData : BaseClass
---@field entities table
---@field recipes table
---@field items table
---@field fluids table
---@field modules Set<string>
---@field transport_belts Set<string>
---@field pipes Set<string>
---@field splitters Set<string>
---@field underground_belts Set<string>
---@field electric_poles Set<string>
---@field assembling_machines Set<string>
---@field beacons Set<string>
---@field machines_with_modules Set<string>
---@field entities_to_avoid Set<string>
---@field size_data SizeData
---@field transport_belt_speeds table<string, float>
---@field reversible_items Set<string>
---@field ticks_per_second int
---@field items_per_belt  int
---@field pipe_throughput_per_second float
---@field barrel_lookup table<string, {barrel_name: string, from_barrel: string?, to_barrel: string?}>
GameData = InheritsFrom(nil)

---get a set of names of entities of a given type
---@param type_name string
---@param collection table<string, any>
---@return Set<string>
function GameData:get_all_from_type(type_name, collection)
    local out = {}
    local to_search = collection
    for _, item in pairs(to_search) do
        if item.type == type_name then
            out[item.name] = true
        end
    end
    return out
end

---Calculate barrel recipe data
---@param recipes GameDataFunctions
---@return table<string, {barrel_name: string, from_barrel: string?, to_barrel: string?}>
local function calculate_barrel_recipes(recipes)
    -- we don't cache the recipes here
    local barrel_recipes = recipes.item_filter("empty-barrel")
    local output = {}

    for recipe_name, _ in pairs(barrel_recipes) do
        local recipe = recipes.lookup(recipe_name)
        if #recipe.ingredients == 2 and #recipe.products == 1 then
            local fluid
            if recipe.ingredients[1].name == "empty-barrel" and recipe.ingredients[2].type == ItemType.FLUID then
                fluid = recipe.ingredients[2].name
            elseif recipe.ingredients[2].name == "empty-barrel" and recipe.ingredients[1].type == ItemType.FLUID then
                fluid = recipe.ingredients[1].name
            end
            if output[fluid] then
                output[fluid].to_barrel = recipe_name
            else
                output[fluid] = {
                    barrel_name = recipe.products[1].name,
                    to_barrel = recipe_name,
                    category = recipe.category
                }
            end
        elseif #recipe.ingredients == 1 and #recipe.products == 2 then
            local fluid
            if recipe.products[1].name == "empty-barrel" and recipe.products[2].type == ItemType.FLUID then
                fluid = recipe.products[2].name
            elseif recipe.products[2].name == "empty-barrel" and recipe.products[1].type == ItemType.FLUID then
                fluid = recipe.products[1].name
            end
            if output[fluid] then
                output[fluid].from_barrel = recipe_name
            else
                output[fluid] = {
                    barrel_name = recipe.ingredients[1].name,
                    from_barrel = recipe_name,
                    category = recipe.category
                }
            end
        end
    end
    return output
end

---@class GameDataFunctions
---@field lookup fun(entry: string)
---@field type_filter fun(type_name: string): Set<string>
---@field item_filter fun(item_name: string): Set<string>
---@field all_data fun():table<string, any>

---Initialized a GameData object
---@param entities GameDataFunctions
---@param recipes GameDataFunctions
---@param items GameDataFunctions
---@param fluids GameDataFunctions
---@return GameData?
function GameData.initialize(entities, recipes, items, fluids)
    local self = GameData:create()

    -- Create all the caches
    self.recipes = Cache.new(function(key)
        local recipe = recipes.lookup(key)
        if recipe == nil then return nil end
        local value = Recipe.from_json(recipe)
        return value
    end)
    self.entities = Cache.new(function(key)
        local value = entities.lookup(key)
        return value
    end)
    self.items = Cache.new(function(key)
        local value = items.lookup(key)
        return value
    end)
    self.fluids = Cache.new(function(key)
        local value = fluids.lookup(key)
        return value
    end)

    self.modules = items.type_filter("module")
    self.transport_belts = entities.type_filter("transport-belt")
    self.pipes = entities.type_filter("pipe")
    self.splitters = entities.type_filter("splitter")
    self.underground_belts = entities.type_filter("underground-belt")
    self.electric_poles = entities.type_filter("electric-pole")
    self.assembling_machines = entities.type_filter("assembling-machine")
    self.beacons = entities.type_filter("beacon")

    self.barrel_lookup = calculate_barrel_recipes(recipes)

    self.machines_with_modules = {}

    local all_entities = entities.all_data()
    for name, entity in pairs(all_entities) do
        if entity.module_inventory_size ~= nil and entity.module_inventory_size > 0 then
            self.machines_with_modules[name] = true
        end
    end
    self.entities_to_avoid = { explosion = true, projectile = true, corpse = true, ["simple-entity"] = true, tree = true }
    self.size_data = {}
    for name, entity in pairs(all_entities) do
        if (not ((entity.tile_width == 1 and entity.tile_height == 1) or
                (entity.tile_width == 0 and entity.tile_height == 0))) and
            self.entities_to_avoid[entity.type] == nil then
            self.size_data[name] = { width = entity.tile_width, height = entity.tile_height }
        end
    end


    self.ticks_per_second = 60
    self.items_per_belt = 8
    ---@type table<string, float>
    self.transport_belt_speeds = {}
    for belt, _ in pairs(self.transport_belts) do
        self.transport_belt_speeds[belt] = self.entities[belt].belt_speed * self.ticks_per_second * self.items_per_belt
    end

    -- from https://wiki.factorio.com/Fluid_system#Transport
    -- however, throughput can be increased by using more pumps
    ---@type float
    self.pipe_throughput_per_second = 1000.0

    ---@type Set<string>
    self.reversible_items = {}
    for item, _ in pairs(self.transport_belts) do
        self.reversible_items[item] = true
    end
    for item, _ in pairs(self.splitters) do
        self.reversible_items[item] = true
    end
    for item, _ in pairs(self.underground_belts) do
        self.reversible_items[item] = true
    end

    return self
end

---Print out this GameData
function GameData:print(printer)
    if printer == nil then
        printer = print
    end
    for key, value in pairs(self) do
        printer(key)
        printer(Dump(value))
        printer("\n")
    end
end

---get the underground version of a belt
---@param belt_name string
---@return string
function GameData:get_underground_for_belt(belt_name)
    return self.entities[belt_name].related_underground_belt
end

---Get fluid boxes for an entity
---@param entity_name string
---@return Fluidbox[] | nil
function GameData:get_fluidboxes_for_entity(entity_name)
    local entity = self.entities[entity_name]
    if entity == nil then return nil end
    local fluidboxes = {}
    for _, fluidbox in ipairs(entity.fluidbox_prototypes) do
        local coordinates = fluidbox.pipe_connections[1].positions[1]
        table.insert(fluidboxes,
            { type = fluidbox.production_type, x = coordinates.x, y = coordinates.y, index = fluidbox.index })
    end
    return fluidboxes
end

-- assert(Table_count(MODULES) > 0)
-- assert(Table_count(TRANSPORT_BELTS) > 0)
-- assert(Table_count(PIPES) > 0)
-- assert(Table_count(SPLITTERS) > 0)
-- assert(Table_count(UNDERGROUND_BELTS) > 0)
-- assert(Table_count(ELECTRIC_POLES) > 0)
-- assert(Table_count(ASSEMBLING_MACHINES) > 0)
-- assert(Table_count(BEACONS) > 0)

-- -@type Set<string> set of strings
-- MACHINES_WITH_MODULES = {}
-- for name, entity in pairs(ALL_ENTITIES) do
--     if entity.module_inventory_size ~= nil and entity.module_inventory_size > 0 then
--         MACHINES_WITH_MODULES[name] = true
--     end
-- end

-- assert(Table_count(MACHINES_WITH_MODULES) > 0)

-- ENTITIES_TO_AVOID = { explosion = true, projectile = true, corpse = true, ["simple-entity"] = true, tree = true }

-- @type table<string, {width: int, height: int}>
-- SIZE_DATA = {}
-- for name, entity in pairs(ALL_ENTITIES) do
--     if (not ((entity.tile_width == 1 and entity.tile_height == 1) or
--             (entity.tile_width == 0 and entity.tile_height == 0))) and
--         ENTITIES_TO_AVOID[entity.type] == nil then
--         SIZE_DATA[name] = { width = entity.tile_width, height = entity.tile_height }
--     end
-- end

-- assert(Table_count(SIZE_DATA) > 0)

-- TICKS_PER_SECOND = 60
-- ITEMS_PET_BELT = 8
-- ---@type table<string, float>
-- TRANSPORT_BELT_SPEEDS = {}
-- for belt, _ in pairs(TRANSPORT_BELTS) do
--     TRANSPORT_BELT_SPEEDS[belt] = ALL_ENTITIES[belt].belt_speed * TICKS_PER_SECOND * ITEMS_PET_BELT
-- end

-- assert(Table_count(TRANSPORT_BELT_SPEEDS) > 0)

-- ---get the underground version of a belt
-- ---@param belt_name string
-- ---@return string
-- function Get_underground_for_belt(belt_name)
--     return ALL_ENTITIES[belt_name].related_underground_belt
-- end

-- assert(Get_underground_for_belt("transport-belt") == "underground-belt")

-- -- from https://wiki.factorio.com/Fluid_system#Transport
-- -- however, throughput can be increased by using more pumps
-- ---@type float
-- PIPE_THROUGHPUT_PER_SECOND = 1000.0

-- ---@type Set<string>
-- REVERSIBLE_ITEMS = {}
-- for item, _ in pairs(TRANSPORT_BELTS) do
--     REVERSIBLE_ITEMS[item] = true
-- end
-- for item, _ in pairs(SPLITTERS) do
--     REVERSIBLE_ITEMS[item] = true
-- end
-- for item, _ in pairs(UNDERGROUND_BELTS) do
--     REVERSIBLE_ITEMS[item] = true
-- end

-- assert(Table_count(REVERSIBLE_ITEMS) > 0)
