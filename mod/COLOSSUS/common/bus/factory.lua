-- Factory objects

require("common.factorio_objects.blueprint")
require("common.factory_components.bundle")
require("common.config.config")
require("common.factory_components.template")
require("common.schematic.diagram")
require("common.config.game_data")
require("common.factorio_objects.item")
require("common.factory_components.lane")
require("common.custom_recipe")
require("common.factorio_objects.recipe")
require("common.transformations")
require("common.bus.algorithms")
require("common.bus.post_processing")

require("common.data_structures.interval_graph")

require("common.utils.objects")
require("common.utils.utils")

require("common.bus.debug")

---@class Factory : BaseClass
---@field recipe_factories RecipeFactory[]
---@field bundles OverlappingBundle[]
---@field base_inputs string[]
---@field config FullConfig
---@field post_processing any[]
Factory = InheritsFrom(nil)

---Create a new Factory object
---@param recipe_factories RecipeFactory[]
---@param bundles OverlappingBundle[]
---@param base_inputs string[]
---@param config FullConfig
---@return Factory
function Factory.new(recipe_factories, bundles, base_inputs, config)
    local self = Factory:create()
    self.recipe_factories = recipe_factories
    self.bundles = bundles
    self.base_inputs = base_inputs
    self.config = config
    self.post_processing = { PostProcessing.connect_clocked_poles, PostProcessing.connect_electrical_grids }
    return self
end

---Create a Factory from a FullRecipe
---@param full_recipe FullRecipe
---@param config FullConfig
---@return Factory
function Factory.from_full_recipe(full_recipe, config)
    local debug = config.bus_debug_logger
    debug:print_recipe(full_recipe)
    local lanes = Algorithms.generate_lanes(full_recipe, config)
    debug:print_lanes(lanes)

    local buffers = Algorithms.generate_buffers(full_recipe, config.fluids_only)
    local full_recipe = full_recipe:set_recipes(Concat_arrays(full_recipe.recipes, buffers))
    debug:print_recipe(full_recipe, "Recipe with buffers")
    local lane_ports = Algorithms.hook_up_lanes_and_recipes(full_recipe, lanes, config)
    debug:save_laneports(full_recipe, lanes, lane_ports)
    local flowrate = Algorithms.calculate_flowrate(full_recipe, lanes, lane_ports, config)
    debug:save_flowrate(full_recipe.recipes, lanes, flowrate.data, config)
    Algorithms.add_flowrates_to_buffers(full_recipe, lane_ports, flowrate)

    -- now we use the flowrate to determine if we need to a split a lane
    lanes = Algorithms.split_lanes(full_recipe, lanes, flowrate, config)
    debug:print_lanes(lanes, "Split lanes")
    local initial_flowrate = Algorithms.calculate_initial_flowrate(full_recipe, lanes, config)
    debug:save_flowrate(full_recipe.recipes, lanes, initial_flowrate.data, config, nil,
        "Split lanes initial flowrate")

    -- do we need to split recipes
    full_recipe, lane_ports, flowrate = Algorithms.split_recipes(full_recipe, lanes, lane_ports, initial_flowrate, config)
    debug:print_recipe(full_recipe, "Final Recipe")
    debug:save_flowrate(full_recipe.recipes, lanes, flowrate.data, config, nil, "Final flowrate")

    Algorithms.set_lane_usage(full_recipe, lanes, flowrate)
    debug:save_construction_info_lanes(lanes, full_recipe)
    local intervals = Algorithms.lanes_to_intervals(lanes, #full_recipe.recipes, config)
    local coloring = ColorIntervals(intervals)
    debug:save_lane_colors(coloring, intervals)
    local bundles, bundle_ports = Algorithms.generate_bundles(lanes, coloring, lane_ports, flowrate, config)
    local bypasses = Algorithms.generate_bypasses(bundle_ports)
    debug:save_bypasses(full_recipe, bundles, bypasses)
    debug:save_templates(config.template_data)
    local recipe_factories = Algorithms.generate_factories(full_recipe, bundles, bundle_ports, bypasses, config)

    debug:save_construction_info_bundles(bundles, full_recipe)

    local items = {}
    for item, _ in pairs(full_recipe:get_base_inputs()) do
        table.insert(items, item)
    end

    debug:close()

    return Factory.new(recipe_factories, bundles, items, config)
end

---Create a blueprint from this Factory
---@return Blueprint
function Factory:to_blueprint()
    local diagram = Empty.new()
    for _, rf in ipairs(self.recipe_factories) do
        diagram = Beside(diagram, rf:to_diagram(), Direction.UP)
    end

    -- add lane info with a gap of 1
    diagram = Beside(diagram, self:lane_info_diagram(), Direction.UP, 1)

    -- set the belts and inserters
    diagram = diagram:act(Transformation.map(Transformations.transform_entity(self.config)))
    -- clocking
    if not self.config.clocked then
        diagram = diagram:act(Transformation.map(Transformations.removed_clocked(self.config)))
    end
    if self.config.tile_style == TileStyle.rectangle and self.config.tile then
        local tile_region = diagram:envelope():to_region()
        RegionTags.tile.set_tag(tile_region, self.config.tile)
        diagram = diagram:add_regions({ tile_region })
    end
    local compiled, regions = diagram:compile()
    local optimizations = {}
    for _, name in ipairs(self.config.optimizations) do
        table.insert(optimizations, Config.OPTIMIZATIONS[name])
    end
    return Primitives_to_blueprint(
        compiled,
        regions,
        optimizations,
        self.post_processing,
        self.config
    )
end

---Use constant combinators to create lane info
---@return Diagram
function Factory:lane_info_diagram()
    local diagram = Empty.new()
    for _, bundle in ipairs(self.bundles) do
        diagram = Beside(diagram, bundle:draw_lane_info(), Direction.LEFT, 3)
    end
    return Translate(-3, 0, diagram)
end
