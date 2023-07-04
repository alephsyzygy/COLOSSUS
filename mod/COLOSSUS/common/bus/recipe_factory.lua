--- A factory line that works on a single recipe

require("common.utils.objects")

---@class RecipeFactory : BaseClass
---@field recipe_info RecipeInfo
---@field idx int recipe index
---@field clocked_template ClockedTemplate
---@field bundle_ports BundlePort[]
---@field bundles OverlappingBundle[]
---@field bypasses BundleBypass[]
---@field full_config FullConfig
RecipeFactory = InheritsFrom(nil)

---Create a new RecipeFactory
---@param recipe_info RecipeInfo
---@param idx int
---@param clocked_template ClockedTemplate
---@param bundle_ports BundlePort[]
---@param bundles OverlappingBundle[]
---@param bypasses BundleBypass[]
---@param full_config FullConfig
---@return RecipeFactory
function RecipeFactory.new(recipe_info, idx, clocked_template, bundle_ports, bundles, bypasses, full_config)
    local self = RecipeFactory:create()
    self.recipe_info = recipe_info
    self.idx = idx
    self.clocked_template = clocked_template
    self.bundle_ports = bundle_ports
    self.bundles = bundles
    self.bypasses = bypasses
    self.full_config = full_config
    return self
end

---Create the diagram for this RecipeFactory
---@return Diagram
function RecipeFactory:to_diagram()
    -- Step 1: create template
    -- Can have some variations from recipe
    local diagram = self.clocked_template.template:get_template()

    ---@type table<int, {name: string, flowrate: float}>
    local flowrates = {}
    local num_item_outputs = 0
    local item_outputs = {}
    if self.recipe_info.recipe_type == RecipeType.BUFFER then
        -- special case for buffers
        diagram = diagram:act(Transformation.map(Transformations.set_pump_condition(
            self.recipe_info.recipe.inputs[1]
        )))
    else
        -- set flowrates
        ---@type table<int, {name: string, flowrate: float}>
        local fluid_flowrates = {}

        for _, bundle_port in ipairs(self.bundle_ports) do
            if (bundle_port.port_type == PortType.ITEM_INPUT or
                    bundle_port.port_type == PortType.FLUID_INPUT) and
                bundle_port.port_idx ~= nil then
                local rate = self.clocked_template.flow_rates[bundle_port.item_name]
                if not rate then
                    error("Rate is none")
                end
                if bundle_port.port_type == PortType.ITEM_INPUT then
                    flowrates[bundle_port.port_idx] = { name = bundle_port.item_name, flowrate = rate }
                else
                    fluid_flowrates[bundle_port.port_idx] = {
                        name = bundle_port.item_name,
                        flowrate = rate
                    }
                end
            elseif bundle_port.port_type == PortType.ITEM_OUTPUT then
                -- record and count number of item outputs
                num_item_outputs = num_item_outputs + 1
                item_outputs[bundle_port.port_idx] = bundle_port.item_name
            end
        end

        -- diagram = diagram:act(Transformation.map(Transformations.set_flowrates(flowrates, self.full_config)))
        diagram = diagram:act(Transformation.map(Transformations.set_fluid_flowrates(fluid_flowrates)))
    end

    -- if there are more than one item outputs
    diagram = diagram:act(Transformation.map(Transformations.set_output_filters(item_outputs, self.full_config)))

    -- Step 2: Create machines
    -- ask the template to do it for us

    local machines = self.clocked_template.template:get_machines(
        math.ceil(self.recipe_info.machine_count)
    )
    -- set the machine info for all the machines
    local transform = Transformation.map(Transformations.set_assembling_machine_details(
        self.recipe_info, self.full_config))
    machines = machines:act(transform)
    diagram = Beside(diagram, machines)

    -- special case: one machine and beacon requested
    -- if math.ceil(self.recipe_info.machine_count) == 1 and
    --     self.recipe_info.beacon_name and
    --     not self.recipe_info.custom_recipe then
    --     local beacon_diagram = self.full_config.blueprint_data.misc_blueprints["beacon"]:to_primitive(self.full_config
    --         .game_data.size_data):act(transform)
    --     diagram = Beside(diagram, beacon_diagram, Direction.RIGHT)
    -- end


    -- Step 3: Calculate lane construction data
    local bundle_construct_data = {}
    local port_names = {}
    for overlapping_bundle_idx, overlapping_bundle in ipairs(self.bundles) do
        ---@type {index: int, coord: int, type: PortType}[][]
        local taps = {}
        for bundle_idx, bundle in ipairs(overlapping_bundle.bundles) do
            local bundle_taps = {}
            for _, bundle_port in ipairs(self.bundle_ports) do
                if bundle_port.bundle_idx == overlapping_bundle_idx and bundle_port.strand_idx == bundle_idx then
                    if bundle_port.port_idx == nil then
                        error("No port index found")
                    end
                    local port = self.clocked_template.template:get_port(bundle_port)
                    if port == nil then
                        error("Could not find port")
                    end
                    table.insert(port_names, port.name)
                    table.insert(bundle_taps, {
                        index = bundle_port.strand_idx,
                        coord = port.coord,
                        type = port.port_type,
                        port = port,
                    })
                end
            end
            table.insert(taps, bundle_taps)
        end
        ---@type {coord: int, type: PortType}[]
        local bypasses = {}
        for _, bypass in ipairs(self.bypasses) do
            if bypass.bundle_idx == overlapping_bundle_idx then
                if bypass.port.port_idx == nil then
                    error("No port index found")
                end
                local port = self.clocked_template.template:get_port(bypass.port)
                if port == nil then
                    print(Dump(bypass.port))
                    print(Dump(self.clocked_template.template.ports))
                    error("Could not find port")
                end
                table.insert(bypasses, {
                    coord = port.coord,
                    type = port.port_type,
                })
            end
        end

        -- now create the wire bypasss
        if self.full_config.clocked then
            local wire_port = self.clocked_template.template:get_port(BundlePort.new(0, 0, "", PortType.WIRE,
                DEFAULT_PORT_INDEX,
                LanePriority.NORMAL))
            if wire_port then
                table.insert(bypasses, { coord = wire_port.coord, type = PortType.WIRE })
            end
        end

        bundle_construct_data[overlapping_bundle_idx] = { taps = taps, bypasses = bypasses }
    end

    -- Step 4: remove unused entities and re-calculate envelope

    -- remove entities associate to unused ports
    diagram = diagram:act(Transformation.map(Transformations.remove_unused_port_entitites(port_names)))
    local first_envelope = diagram:envelope()

    -- Force a compile to re-calculate the envelope
    -- TODO improve this
    local compiled_lane, compiled_regions = diagram:compile()
    local concat_compiled_lane = Concat_primitives_with_delete(compiled_lane)

    diagram = Primitive.new(Primitives_to_actions(concat_compiled_lane))
    diagram = diagram:act(Transformation.map(Transformations.set_timescale(self.clocked_template.timescale * 60)))
    diagram = diagram:act(Transformation.map(Transformations.set_start_time()))
    local second_envelope = diagram:envelope()

    -- Readjust envelope from metadata
    local final_envelope = diagram:envelope()
    if final_envelope == nil then error("When creating a row the final envelope was nil") end
    -- note: up and down are inverted here
    local envelope_up = MetadataTags["envelope-up"].get_tag(self.clocked_template.template.tags)
    local envelope_down = MetadataTags["envelope-down"].get_tag(self.clocked_template.template.tags)
    if envelope_up then
        final_envelope.down = final_envelope.down + envelope_up
    end
    if envelope_down then
        final_envelope.up = final_envelope.up + envelope_down
    end

    diagram = diagram:set_envelope(final_envelope)
    local envelope = diagram:envelope()
    if envelope == nil then
        error("Envelope is none for index " .. self.idx)
    end
    local template_envelope = envelope

    local height = envelope.up + envelope.down + 1

    -- Step 5: construct lanes
    for overlapping_bundle_idx, overlapping_bundle in ipairs(self.bundles) do
        local taps = bundle_construct_data[overlapping_bundle_idx].taps
        local bypasses = bundle_construct_data[overlapping_bundle_idx].bypasses
        local bundle_diagram = overlapping_bundle:draw_bundle(self.idx, height, -envelope.down, taps, bypasses,
            self.full_config, flowrates, self.recipe_info.recipe_type)
        local bundle_region = bundle_diagram:envelope():to_region()

        -- RegionTags.lane.set_tag(bundle_region, true)
        bundle_diagram = bundle_diagram:add_regions({ bundle_region })
        diagram = Beside(diagram, bundle_diagram, Direction.LEFT)
    end


    local full_envelope = diagram:envelope()
    if full_envelope == nil then error("Error generating envelope, this should not happend") end
    local special_envelope = template_envelope:clone()
    -- warning: this relies on diagram always being the first entry to Beside() in the above code
    special_envelope.left = full_envelope.left
    local region = diagram:envelope():to_region()
    local special_region = special_envelope:to_region()
    -- region.tags["tile"] = "concrete"
    -- special_region.tags["tile"] = "hazard-concrete-left"
    if self.recipe_info.recipe_type ~= RecipeType.BUFFER and self.full_config.clocked then
        RegionTags.clocked.set_tag(special_region, true)
        RegionTags["clocked-red-wire"].set_tag(special_region, true)
        RegionTags.clocked.set_tag(region, true)
    end
    RegionTags.recipe.set_tag(region, self.recipe_info.recipe.name)
    RegionTags.recipe.set_tag(special_region, self.recipe_info.recipe.name)
    if self.full_config.tile_style == TileStyle.jagged and self.full_config.tile then
        local jagged = diagram:envelope():to_region()
        RegionTags.tile.set_tag(jagged, self.full_config.tile)
        diagram = diagram:add_regions({ special_region, region, jagged })
    else
        diagram = diagram:add_regions({ special_region, region })
    end

    return diagram
end
