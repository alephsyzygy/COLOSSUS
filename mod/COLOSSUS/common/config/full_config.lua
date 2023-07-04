-- full configuration object

require("common.config.config")
require("common.utils.logger")

---@alias TemplateData {blueprint: string, name:string, description:string|nil, icons:string[], row_tags:table<string,string>, col_tags:table<string,string>, metadata_tags:table<string,string>}

---@class FullConfig : Config
---@field game_data GameData
---@field blueprint_data BlueprintData
---@field template_factory table<string, Template>
---@field category_to_template table<string, Template>
---@field custom_recipes table<string, CustomRecipe>
---@field replacement_info? table<string, {entity: string, max_distance: int}>
---@field bypass_data table<string, Primitive>
---@field bundle_data table<string, table<string, Primitive>>
---@field lane_data table<string, Primitive>
---@field blueprint_name string
---@field template_data {template_data: TemplateData, metadata: TemplateMetadata, template: Template|nil, template_builder: function|nil}[]
---@field loaded_mods table<string, string>
---@field loaded_mods_set Set<string>
---@field bus_debug_logger DebugBus
---@field logger Logger
FullConfig = InheritsFrom(Config)

---Create a new FullConfig object
---@param config Config
---@param game_data GameData
---@param blueprint_data BlueprintData
---@param template_data TemplateData
---@param bus_debug_logger DebugBus
---@param mod_data? table<string, string>
---@return FullConfig
function FullConfig.new(config, game_data, blueprint_data, template_data, bus_debug_logger, mod_data)
    local self = FullConfig:create()
    for k, v in pairs(config) do
        self[k] = v
    end
    self.game_data = game_data
    self.blueprint_data = blueprint_data
    self.blueprint_name = "generated_blueprint"
    self.template_data = {}
    for _, template in pairs(template_data) do
        table.insert(self.template_data,
            { template_data = template, metadata = TemplateMetadata.from_tags(template.metadata_tags, game_data) })
    end
    if mod_data == nil then
        self.loaded_mods = {}
        self.loaded_mods_set = {}
    else
        self.loaded_mods = mod_data
        self.loaded_mods_set = Table_keys_set(mod_data)
    end
    self.bus_debug_logger = bus_debug_logger
    self.logger = Logger.new()

    return self
end

---returns float of max belt flowrate
---@return float
function FullConfig:get_max_belt_flowrate()
    return self.game_data.transport_belt_speeds[self.belt_item_name]
end

---returns float of max pipe flowrate
---@return float
function FullConfig:get_max_pipe_flowrate()
    return self.game_data.pipe_throughput_per_second
end

---get max flowrate of item type over timescale
---@param item_type ItemType
---@param timescale int
---@return float
function FullConfig:get_max_flowrate(item_type, timescale)
    if item_type == ItemType.ITEM or item_type == ItemType.FUEL then
        return self:get_max_belt_flowrate() * timescale
    elseif item_type == ItemType.FLUID then
        return self:get_max_pipe_flowrate() * timescale
    else
        error(string.format("get_max_flowrate: item_type %s is not an ItemType", item_type))
    end
end
