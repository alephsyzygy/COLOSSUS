-- Generic config

require("common.utils.utils")
require("common.factorio_objects.item")
require("common.config.game_data")

require("common.utils.objects")
require("common.optimizer")

---OutputStyle: various bus output styles
---@enum OutputStyle
OutputStyle = {
    down = 1,
    up = 2,
    single = 3,
    passive = 4,
    buffer = 5,
    none = 6
}

---Does this OutputStyle require lane generation?
---@param style OutputStyle
---@return boolean
function OutputStyle.generate_output_lane(style)
    if style == OutputStyle.down or style == OutputStyle.up then
        return true
    end
    return false
end

---TileStyle: various styles of tiling
---@enum TileStyle
TileStyle = {
    none = 1,
    entity = 2,
    jagged = 3,
    rectangle = 4
}

---@class Config : BaseClass
---@field belt_item_name string
---@field belt_underground_name string
---@field pipe_item_name string
---@field pipe_underground_name string
---@field splitter_item_name string
---@field pole string
---@field inserter string
---@field filter_inserter string
---@field long_inserter_name string
---@field pump string
---@field tile? string
---@field tile_style TileStyle
---@field output_style OutputStyle
---@field max_bundle_size int
---@field clocked boolean
---@field ignore_recipe_loops boolean
---@field bus_splitters_prioritized boolean
---@field optimizations string[]
---@field logistic_input string
---@field logistic_output string
---@field logistic_byproduct string
---@field logistic_output_circuit_controlled boolean use circuits to control output rather than reserving spaces
---@field logistic_input_multiplier float how many recipe inputs
---@field logistic_output_multiplier float how many recipe outputs
---@field logistic_final_output_multiplier float how many timescales of output should we keep
---@field logistic_width int width of the logistic area
---@field logistic_roboport string
---@field barrelling_machine string
---@field allow_logistic boolean
---@field console_logging boolean
---@field flowrate_logging boolean
---@field always_show_info_dialog boolean
---@field fluids_only boolean only fluids on the bus
---@field custom_recipes_enabled boolean
---@field print function
---@field technique int full bus, fluid bus, logistic network...
Config = InheritsFrom(nil)

Config.TRANSFORMATION_CONFIG_DATA = {
    belt_chooser = { type = "transport-belt", default = "transport-belt", config_name = "belt_item_name" },
    splitter_chooser = { type = "splitter", default = "splitter", config_name = "splitter_item_name" },
    underground_chooser = {
        type = "underground-belt",
        default = "underground-belt",
        config_name = "belt_underground_name"
    },
    pipe_chooser = { type = "pipe", default = "pipe", config_name = "pipe_item_name" },
    pipe_to_ground_chooser = { type = "pipe-to-ground", default = "pipe-to-ground", config_name = "pipe_underground_name" },
    pole_chooser = { type = "electric-pole", default = "medium-electric-pole", config_name = "pole" },
    inserter_chooser = { type = "inserter", default = "inserter", config_name = "inserter" },
    long_inserter_chooser = { type = "inserter", default = "long-handed-inserter", config_name = "long_inserter_name" },
    barrelling_machine = {
        type = "assembling-machine",
        default = "assembling-machine-2",
        config_name = "barrelling_machine"
    },
    roboport = { type = "roboport", default = "roboport", config_name = "logistic_roboport" },
}

---@type table<string, function>
Config.OPTIMIZATIONS = {
    optimize_underground_belts = Optimizations.optimize_underground_belts,
    optimize_underground_pipes = Optimizations.optimize_underground_pipes
}

---Create a new Config
---@return Config
function Config.new()
    local self = Config:create()
    self.tile_style = TileStyle.none
    self.output_style = OutputStyle.down
    self.max_bundle_size = 4
    self.clocked = true
    self.ignore_recipe_loops = false
    self.bus_splitters_prioritized = false
    self.optimizations = {}
    self.logistic_input = "logistic-chest-requester"
    self.logistic_output = "logistic-chest-storage" -- logistic-chest-passive-provider
    self.logistic_byproduct = "logistic-chest-active-provider"
    self.logistic_output_circuit_controlled = true
    self.logistic_input_multiplier = 3
    self.logistic_output_multiplier = 3
    self.logistic_final_output_multiplier = 5
    self.logistic_width = 48
    self.allow_logistic = false
    self.fluids_only = false
    self.custom_recipes_enabled = true
    self.technique = 1
    self:set_defaults()
    return self
end

---If some defaults have been removed then reset them
function Config:set_defaults()
    self.belt_item_name = self.belt_item_name or "transport-belt"
    self.belt_underground_name = self.belt_underground_name or "underground-belt"
    self.pipe_item_name = self.pipe_item_name or "pipe"
    self.pipe_underground_name = self.pipe_underground_name or "pipe-to-ground"
    self.splitter_item_name = self.splitter_item_name or "splitter"
    self.pole = self.pole or "medium-electric-pole"
    self.inserter = self.inserter or "inserter"
    self.filter_inserter = self.filter_inserter or "filter-inserter"
    self.long_inserter_name = self.long_inserter_name or "long-handed-inserter"
    self.pump = self.pump or "pump"
    self.barrelling_machine = self.barrelling_machine or "assembling-machine-2"
    self.logistic_roboport = self.logistic_roboport or "roboport"
end
