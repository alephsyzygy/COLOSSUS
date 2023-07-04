require("common.planners.factoryplanner")
require("common.planners.helmod")
require("common.bus.factory")
require("common.logistic.logistic")
require("common.logistic.local_fluid_bus")
require("common.logistic.fluid_bus")
require("common.utils.serdes")
require("common.config.config")
require("common.factory_components.lane")
require("cli.clipboard")
require("cli.initialize")

OS = require("os")
local luaunit = require('lib.luaunit')
serpent = require('lib.serpent')

local function json_loader(directory)
    if directory == nil then
        directory = ""
    end
    return function(filename)
        local data = Load_data("../../buses/" .. directory .. "/" .. filename .. ".json")
        local decompressed_blueprint = Zlib.Zlib.Compress(data)
        return Base64.encode(decompressed_blueprint)
    end
end

local function base64_loader(directory)
    if directory == nil then
        directory = ""
    end
    return function(filename)
        return Load_data("../../buses/" .. directory .. "/" .. filename .. ".b64")
    end
end

local function factoryplanner(data, full_config)
    local factory_object = Serdes:from_string(data, false)
    return Load_factory_planner_bus(factory_object, full_config)
end

local function helmod(data, full_config)
    local factory_object = Import_helmod_string(data)
    return Load_helmod_bus(factory_object, full_config)
end

local function main(filename, make_blueprint, export, builder, loader, planner, disable_custom, directory,
                    config_callback)
    if make_blueprint == nil then
        make_blueprint = false
        export = false
    elseif export == nil then
        export = true
    end

    local config = Config.new()
    config.max_bundle_size = 2
    config.belt_item_name = "transport-belt"
    config.splitter_item_name = "splitter"
    config.optimizations = { "optimize_underground_belts", "optimize_underground_pipes" }
    local full_config = Initialize_game_data(config, directory)
    if full_config == nil then
        error("Full config is nil")
    end

    local name = filename .. "@" .. OS.date("%Y-%m-%dT%H:%M:%S")
    full_config.blueprint_name = name

    if config_callback then
        config_callback(full_config)
    end
    local data = loader(filename)

    -- local factory_object = Serdes:from_string(data, false)

    if disable_custom then
        full_config.custom_recipes = {}
    end

    -- local factory = Load_factory_planner_bus(factory_object, full_config)
    local factory = planner(data, full_config)
    local recipe = builder(factory, full_config)
    -- -- this is the major step, so wrap it in an xpcall
    -- local function error_handler(err)
    --     debug.traceback()
    --     print(err)
    -- end
    -- local function from_full_recipe()
    --     return builder(factory, full_config)
    -- end
    -- local status, recipe, err = xpcall(from_full_recipe, error_handler)
    -- if not status then
    --     error(err)
    -- end
    if recipe == nil then
        error("Recipe is nil")
    end
    if make_blueprint then
        local blueprint = recipe:to_blueprint()
        if export then
            local blueprint_string = blueprint:export()
            Copy_to_clipboard(blueprint_string)
            print("Copied to clipboard")
        end
    end
end

local function remove_templates(config)
    config.template_data = {}
end


TestIntegration = {}

local function init()
    local filenames = { "byproduct", "byproducts", "electronic_circuit", "fluidtest", "processor",
        "science2", "science2_big", "science2_pseudo", "science3", "science3_fast", "science3_pseudo",
        "science5", "science5_matrix", "steel", "sulfur", "science1", "centrifuge" }
    local recipe_only = {}
    local deprecated = { "space_basic", "space1000", "space", "rocket_silo", } -- replaced by newer JSON format
    for _, filename in ipairs(filenames) do
        TestIntegration["test" .. filename] = function()
            main(filename, true, false, Factory.from_full_recipe, base64_loader(), factoryplanner)
        end
        TestIntegration["test" .. filename .. "-logistic"] = function()
            main(filename, true, false, Logistic.from_full_recipe, base64_loader(), factoryplanner, true)
        end
        TestIntegration["test" .. filename .. "-fluid_bus"] = function()
            main(filename, true, false, FluidBus.from_full_recipe, base64_loader(), factoryplanner, true)
        end
    end
    TestIntegration["test-removed-templates"] = function()
        main("science2", true, false, Factory.from_full_recipe,
            base64_loader(), factoryplanner, nil, nil, remove_templates)
    end
    for _, filename in ipairs(recipe_only) do
        TestIntegration["test" .. filename] = function()
            main(filename, false, false, Factory.from_full_recipe, base64_loader, factoryplanner)
        end
        TestIntegration["test" .. filename .. "-logistic"] = function()
            main(filename, true, false, Logistic.from_full_recipe, base64_loader(), factoryplanner)
        end
        TestIntegration["test" .. filename .. "-fluid_bus"] = function()
            main(filename, true, false, FluidBus.from_full_recipe, base64_loader(), factoryplanner)
        end
    end
    local json_filenames = { "space-basic", "steel", "rocket_silo", "space_science", "rocket_fuel" }
    local json_recipeonly = { "all1000" } -- 146 seconds for full
    for _, filename in ipairs(json_filenames) do
        TestIntegration["test" .. filename .. "-json"] = function()
            main(filename, true, false, Factory.from_full_recipe, json_loader(), factoryplanner)
        end
        TestIntegration["test" .. filename .. "-json-logistic"] = function()
            main(filename, true, false, Logistic.from_full_recipe, json_loader(), factoryplanner, true)
        end
    end
    for _, filename in ipairs(json_recipeonly) do
        TestIntegration["test" .. filename .. "-json"] = function()
            main(filename, false, false, Factory.from_full_recipe, json_loader(), factoryplanner)
        end
        TestIntegration["test" .. filename .. "-json-logistic"] = function()
            main(filename, false, false, Logistic.from_full_recipe, json_loader(), factoryplanner, true)
        end
    end
    local se = { "vulcanite" } --, "cryonite-rod" }
    for _, filename in ipairs(se) do
        TestIntegration["test-se-" .. filename .. "-json"] = function()
            main(filename, true, false, Factory.from_full_recipe, json_loader("space-exploration"), factoryplanner, true,
                "../../data/space-exploration")
        end
    end

    local helmod_filenames = { "chemical_science_modules" }
    for _, filename in ipairs(helmod_filenames) do
        TestIntegration["test-helmod-" .. filename] = function()
            main(filename, true, false, Factory.from_full_recipe, base64_loader("helmod"), helmod)
        end
    end
end

init()
TestIntegration["test-sulfur-local_fluid_bus"] = function()
    main('sulfur', true, false, LocalFluidBus.from_full_recipe,
        base64_loader(), factoryplanner)
end
TestIntegration["test-byproduct-local_fluid_bus"] = function()
    main('byproduct', true, false, LocalFluidBus.from_full_recipe,
        base64_loader(), factoryplanner)
end

---Enable fluid bus
---@param config FullConfig
local function enable_fluid_bus(config)
    config.allow_logistic = true
    local metadata = TemplateMetadata.from_tags({})
    metadata.priority = 5001
    metadata.fluid_inputs = 255
    metadata.fluid_outputs = 255
    metadata.is_generic = true
    metadata.size_generic = true
    metadata.fluidbox_generic = true

    local metadata_logistic = Deepcopy(metadata)
    metadata_logistic.uses_logistic_network = true
    metadata_logistic.item_inputs = 255
    metadata_logistic.item_outputs = 255
    metadata_logistic.item_loops = 255
    metadata.priority = 5000
    table.insert(config.template_data,
        {
            template_data = { name = "Local Fluid Bus" },
            metadata = metadata,
            template_builder = LocalFluidBus.create_template
        })
    table.insert(config.template_data,
        {
            template_data = { name = "Local Fluid Bus & Logistic" },
            metadata = metadata_logistic,
            template_builder = LocalFluidBus.create_template
        })
end

---Enable fluid bus
---@param config FullConfig
local function enable_fluid_bus2(config)
    config.allow_logistic = true
    config.fluids_only = true
    local metadata = TemplateMetadata.from_tags({})
    metadata.priority = 5001
    metadata.fluid_inputs = 255
    metadata.fluid_outputs = 255
    metadata.is_generic = true
    metadata.size_generic = true
    metadata.fluidbox_generic = true

    local metadata_logistic = Deepcopy(metadata)
    metadata_logistic.uses_logistic_network = true
    metadata_logistic.item_inputs = 255
    metadata_logistic.item_outputs = 255
    metadata_logistic.item_loops = 255
    metadata.priority = 5000
    table.insert(config.template_data,
        {
            template_data = { name = "Local Fluid Bus" },
            metadata = metadata,
            template_builder = LocalFluidBus.create_template
        })
    table.insert(config.template_data,
        {
            template_data = { name = "Local Fluid Bus & Logistic" },
            metadata = metadata_logistic,
            template_builder = LocalFluidBus.create_template
        })
end

TestIntegration["test-byproduct-fluid_bus"] = function()
    main('byproduct', true, false, Factory.from_full_recipe,
        base64_loader(), factoryplanner, nil, nil, enable_fluid_bus)
end
TestIntegration["test-sulfur-fluid_bus"] = function()
    main('sulfur', true, false, Factory.from_full_recipe,
        base64_loader(), factoryplanner, nil, nil, enable_fluid_bus2)
end
-- TestIntegration["test" .. "space"]()
---@diagnostic disable-next-line: undefined-field
if _G.ALL_TESTS == nil then
    OS.exit(luaunit.LuaUnit.run())
end
