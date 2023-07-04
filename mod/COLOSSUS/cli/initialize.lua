IO = require("io")
JSON = require("lib.JSON")

require("common.config.game_data")
require("common.factorio_objects.blueprint")
require("common.factory_components.template")
require("common.custom_recipe")
require("common.config.full_config")

require("common.bus.debug")

require("data.blueprint_data")
require("data.template_data")

local file = nil

local function init_file()
    file = assert(IO.open("flowrate.txt", "w"))
end

local function write_file(data)
    file:write(data)
end

-- TODO write_timestamp_file support

local function close_file()
    file:close()
end

function Load_json_data(filename, versioned)
    local file = assert(IO.open(filename, "r"))
    local data = file:read("*a")
    if versioned == true then
        data = data:sub(2)
    end
    local json_data = JSON:decode(data)
    file:close()
    if json_data == nil then
        error("JSON data is nil")
    end

    return json_data
end

function Load_data(filename, versioned)
    local file = assert(IO.open(filename, "r"))
    local data = file:read("*a")
    file:close()
    return data
end

---Create game data functions
---@param data any
---@return GameDataFunctions
local function create_game_data_functions(data)
    return {
        lookup = function(key) return data[key] end,
        type_filter = function(type_name)
            local out = {}
            for _, item in pairs(data) do
                if item.type == type_name then
                    out[item.name] = true
                end
            end
            return out
        end,
        item_filter = function(item_name)
            local out = {}
            for _, recipe in pairs(data) do
                for _, ingredient in pairs(recipe.ingredients) do
                    if ingredient.name == item_name then out[recipe.name] = true end
                end
                for _, product in pairs(recipe.products) do
                    if product.name == item_name then out[recipe.name] = true end
                end
            end
            return out
        end,
        all_data = function() return data end
    }
end

---Initialize FullConfig from a Config object
---@param config Config
---@param directory? string
---@return FullConfig
function Initialize_game_data(config, directory)
    if directory == nil then directory = "data" end
    local recipes = create_game_data_functions(Load_json_data(directory .. "/recipes.json"))
    local items = create_game_data_functions(Load_json_data(directory .. "/items.json"))
    local entities = create_game_data_functions(Load_json_data(directory .. "/entities.json"))
    local fluids = create_game_data_functions(Load_json_data(directory .. "/fluids.json"))
    local game_data = GameData.initialize(entities, recipes, items, fluids)
    if game_data == nil then
        error("Could not initialize game data")
    end

    local blueprint_data = BlueprintData.initialize(BLUEPRINT_BOOK_DATA)
    local template_data = CONNECTOR_DATA

    local full_config = FullConfig.new(config, game_data, blueprint_data, template_data,
        DebugBus.new(init_file, write_file, write_file, close_file))

    TemplateFactory_init(full_config)
    CustomRecipe_init(full_config)

    return full_config
end
