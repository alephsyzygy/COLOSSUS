require("common.planners.factoryplanner")
require("common.bus.factory")
require("common.logistic.logistic")
require("common.logistic.fluid_bus")
require("common.utils.serdes")
require("common.config.config")
require("common.factory_components.lane")

require("factorio.initialize")

TECHNIQUES = {
    {
        name = "bus",
        caption = "colossus.technique.bus",
        builder = Factory.from_full_recipe,
        custom_recipes = true
    },
    {
        name = "fluid_bus",
        caption = "colossus.technique.fluid_bus",
        builder = FluidBus
            .from_full_recipe
    },
    {
        name = "logistic",
        caption = "colossus.technique.logistic",
        builder = Logistic
            .from_full_recipe
    },
    { name = "logistic_with_fluid_bus", caption = "colossus.technique.logistic_with_fluid_bus", builder = nil }
}

---Main routine for building a bus
---@param player_index uint
---@param data table
---@param config Config
---@param loader fun(factory_object: any, full_config: FullConfig)
function Main(player_index, data, config, loader)
    local player = game.get_player(player_index)
    local player_global = global.players[player_index]
    player_global.current_blueprint = nil
    if player == nil then
        error("Failed to get player")
    end
    local builder = TECHNIQUES[config.technique].builder
    if builder == nil then
        error(string.format("Technique %s not implemented yet", TECHNIQUES[config.technique].name))
    end
    if not TECHNIQUES[config.technique].custom_recipes then
        config.custom_recipes_enabled = false
    end

    local profiler = game.create_profiler()
    if config.console_logging then
        config.print = function(msg)
            player.print({ "", profiler, " ", msg })
        end
    else
        config.print = function(msg) end
    end
    config.print("=== Starting ===")

    game.write_file("remote_recipe.json", game.table_to_json(data))
    local factory_object = data

    local full_config = FactorioInitializer.initialize_game_data(player_index, config, profiler)
    full_config.print("Data initialized")
    if full_config.output_style ~= OutputStyle.down and full_config.output_style ~= OutputStyle.none and full_config.output_style ~= OutputStyle.up then
        full_config.logger:warn("The selected output style is not yet implemented.")
    end

    -- local factory_object = Serdes:from_string(data, false)
    local factory, filename = loader(factory_object, full_config)
    local name = filename .. "@" .. game.tick
    full_config.blueprint_name = name
    full_config.print("Factory loaded")

    -- this is the major step, so wrap it in an xpcall
    local function error_handler(err)
        -- full_config.print(err)
        full_config.logger:error(debug.traceback(err, 2))
        -- local table = serpent.block({ factory = factory, config = full_config })
        -- game.write_file("COLOSSUS_crash_log." .. game.tick .. ".lua", table)
    end
    local function from_full_recipe()
        return builder(factory, full_config)
    end
    local status, recipe = xpcall(from_full_recipe, error_handler)
    if not status then
        InfoScreen.show_screen(player, player_global, full_config.logger)
        return
    end
    if recipe == nil then
        full_config.logger:error("Recipe is nil")
        InfoScreen.show_screen(player, player_global, full_config.logger)
        return
    end

    full_config.print("Factory planned")
    local blueprint = recipe:to_blueprint()
    full_config.print("Blueprint created")


    local blueprint_object = { [Blueprint.export_name] = blueprint:to_dict() }
    -- game.write_file("blueprint.object", serpent.block(blueprint_object))
    local blueprint_json = game.table_to_json(blueprint_object)
    local blueprint_string = game.encode_string(blueprint_json)
    player_global.current_blueprint = blueprint_string
    full_config.print("=== Finished ===")
    if full_config.always_show_info_dialog or #full_config.logger.warn_messages > 0 or #full_config.logger.error_messages > 0 then
        InfoScreen.show_screen(player, player_global, full_config.logger)
    else
        Blueprint_to_cursor(player, player_global)
    end
end

function Blueprint_to_cursor(player, player_global)
    -- game.write_file("blueprint.bp", blueprint_string)
    local blueprint_string = player_global.current_blueprint
    if blueprint_string == nil then
        error("Could not encode blueprint string")
    end
    -- full_config.print("Blueprint exported")

    local inventory = game.create_inventory(1)
    -- We need the "0", otherwise the game says the blueprint has not been configured
    if inventory[1].import_stack("0" .. blueprint_string) == 0 then
        -- full_config.print("Import successful")
    else
        -- full_config.print("Failed")
        -- TODO flying text here?
    end

    player.add_to_clipboard(inventory[1])
    player.activate_paste()
    inventory.destroy()
    player_global.current_blueprint = nil
    -- full_config.print("=== Finished ===")
end
