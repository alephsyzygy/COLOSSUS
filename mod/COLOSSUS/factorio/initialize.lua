require("common.config.game_data")
require("common.factorio_objects.blueprint")
require("common.factory_components.template")
require("common.custom_recipe")
require("common.config.full_config")

require("data.blueprint_data")
require("data.template_data")
require("factorio.dump_data")

require("common.bus.debug")

FactorioInitializer = {}

local function create_logger(player_index, profiler)
    local function init()
        game.write_file("flowrate.txt", "", false, player_index)
    end

    local function write(data)
        game.write_file("flowrate.txt", data, true, player_index)
    end

    local function write_timestamp(data)
        game.write_file("flowrate.txt", { "", profiler, " ", data }, true, player_index)
    end

    local function close()
    end
    return DebugBus.new(init, write, write_timestamp, close)
end

local function create_empty_logger(player_index)
    local function init() end
    local function write(data) end
    local function close() end
    return DebugBus.new(init, write, write, close)
end


---Initialize the game data
---@param player_index uint
---@param config Config
---@param profiler LuaProfiler
---@return FullConfig
function FactorioInitializer.initialize_game_data(player_index, config, profiler)
    local debug_logger
    if config.flowrate_logging then
        debug_logger = create_logger(player_index, profiler)
    else
        debug_logger = create_empty_logger(player_index)
    end
    local data = Game_data_lookups()
    -- config.print("Created game data lookups")
    local game_data = GameData.initialize(data.entities, data.recipes, data.items, data.fluids)
    if game_data == nil then
        error("Could not initialize game data")
    end
    -- config.print("GameData intialized")

    local blueprint_data = BlueprintData.initialize(BLUEPRINT_BOOK_DATA) -- slow
    -- config.print("BlueprintData initialized")
    local template_data = CONNECTOR_DATA
    if global.players[player_index].templates then
        template_data = global.players[player_index].templates
    end

    local full_config = FullConfig.new(config, game_data, blueprint_data, template_data, debug_logger, game.active_mods)
    -- config.print("FullConfig intialized")

    TemplateFactory_init(full_config) -- slow
    -- config.print("Templates intialized")
    CustomRecipe_init(full_config)
    -- config.print("Custom Recipes initialized")

    -- game.write_file("GAME_DATA", "", false, player_index)
    -- full_config.game_data:print(function(x) game.write_file("GAME_DATA", x, true, player_index) end)
    -- config.print("GAME_DATA written")
    return full_config
end
