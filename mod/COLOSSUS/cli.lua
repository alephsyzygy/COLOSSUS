require("common.planners.factoryplanner")
require("common.bus.factory")
require("common.utils.serdes")
require("common.config.config")
require("common.factory_components.lane")
require("cli.clipboard")
require("cli.initialize")

OS = require("os")

ProFi = require("lib.ProFi")
GREEN = "\n\x1b[92m"
STOP = "\x1b[0m"

local config = Config.new()
config.max_bundle_size = 2
config.belt_item_name = "transport-belt"
config.splitter_item_name = "splitter"

config.print = print

local full_config = Initialize_game_data(config)
if full_config == nil then
    error("Could not initialize full config")
end


local filename = "science5_matrix"
local name = filename .. "@" .. OS.date("%Y-%m-%dT%H:%M:%S")
full_config.blueprint_name = name
local data = Load_data("../../buses/" .. filename .. ".b64")

local factory_object = Serdes:from_string(data, false)
-- ProFi:start()
local factory = Load_factory_planner_bus(factory_object, full_config)
local recipe = Factory.from_full_recipe(factory, full_config)
local blueprint = recipe:to_blueprint()

-- ProFi:stop()
-- ProFi:writeReport('profile.txt')

-- ProFi:start()
local blueprint_string = blueprint:export()
-- ProFi:stop()
-- ProFi:writeReport('profile_export.txt')

Copy_to_clipboard(blueprint_string, false)
print(GREEN .. "Blueprint Copied to Clipboard" .. STOP .. "\n")
-- print(blueprint_string)
