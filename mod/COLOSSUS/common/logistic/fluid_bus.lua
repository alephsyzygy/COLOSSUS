require("common.utils.objects")
require("common.bus.factory")
require("common.logistic.local_fluid_bus")

---@class FluidBus : BaseClass
---@field factory Factory
---@field config FullConfig
FluidBus = InheritsFrom(nil)

function FluidBus.new(factory, config)
    local self = FluidBus:create()
    self.factory = factory
    self.config = config
    return self
end

---@param full_recipe FullRecipe
---@param config FullConfig
function FluidBus.from_full_recipe(full_recipe, config)
    local buffer
    for _, data in ipairs(config.template_data) do
        if data.metadata.buffer == "fluid" then
            buffer = data
        end
    end
    config.allow_logistic = true
    config.fluids_only = true
    config.custom_recipes = {}
    config.custom_recipes_enabled = false
    local metadata = TemplateMetadata.from_tags({})
    metadata.priority = 100
    metadata.fluid_inputs = 255
    metadata.fluid_outputs = 255
    metadata.is_generic = true
    metadata.size_generic = true
    metadata.fluidbox_generic = true
    metadata.uses_logistic_network = true
    metadata.item_inputs = 255
    metadata.item_outputs = 255
    metadata.item_loops = 255
    config.template_data = { buffer,
        {
            template_data = { name = "Fluid Bus Generic Template" },
            metadata = metadata,
            template_builder = LocalFluidBus.create_template
        } }
    local factory = Factory.from_full_recipe(full_recipe, config)
    return FluidBus.new(factory, config)
end

function FluidBus:to_blueprint()
    self.factory.post_processing = { PostProcessing.connect_electrical_grids }
    return self.factory:to_blueprint()
end
