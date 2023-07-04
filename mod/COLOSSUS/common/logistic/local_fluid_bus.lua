--- Create a local fluid bus

require("common.utils.utils")
require("common.logistic.logistic")
require("common.utils.objects")

-- given a recipe, create the given machines and hook them up to a local fluid bus.
-- top connections connect to the top bus, lower connections connect the the lower bus
-- left and right connections can connect to either.

---@class LocalFluidBus : BaseClass
---@field diagram Diagram
---@field config FullConfig
LocalFluidBus = InheritsFrom(nil)

---Create a new LocalFluidBus object
---@param diagram Diagram
---@param config FullConfig
---@return LocalFluidBus
function LocalFluidBus.new(diagram, config)
    local self = LocalFluidBus:create()
    self.diagram = diagram
    self.config = config
    return self
end

---Create a local fluid bus, returning a diagram of the bus and port info
---@param machine_name string entity name
---@param full_config FullConfig
---@param recipe_info RecipeInfo
---@param timescale int
---@param item_inputs? IngredientItem[]
---@param primary_output? IngredientItem
---@param is_final? boolean
---@param byproducts? IngredientItem[]
---@param fluid_inputs? IngredientItem[]
---@param fluid_outputs? IngredientItem[]
---@return Diagram
---@return Port[]
function LocalFluidBus.create_machine(machine_name, recipe_info, full_config, timescale, item_inputs, primary_output,
                                      is_final, byproducts, fluid_inputs, fluid_outputs)
    if item_inputs == nil then item_inputs = {} end
    if fluid_inputs == nil then fluid_inputs = {} end
    if primary_output == nil then primary_output = {} end
    if byproducts == nil then byproducts = {} end
    if fluid_outputs == nil then fluid_outputs = {} end
    local inputs, outputs, input_outputs, free_directions = Logistic.calculate_fluidbox_info(machine_name, full_config)
    local data = CoordTable.new()
    local direction = EntityDirection.UP
    local entity = Entity.new(machine_name, direction, {}, {})
    local recipe = full_config.game_data.recipes[recipe_info.recipe.name]

    local machine = full_config.game_data.entities[recipe_info.machine_name]
    EntityTags.machine.set_tag(entity, true)
    CoordTable.set(data, 0, 0, ActionPair.new(entity))
    Set_delete_entities(data, machine_name, 0, 0, direction, full_config.game_data.size_data)


    -- not worrying about rotation
    -- up goes up, down goes down, left and right get to decide
    local left_up_idx = 2
    local left_down_idx = 2
    local right_up_idx = 2
    local right_down_idx = 2

    local top_bus = {}
    local top_bus_idx = 2
    local bottom_bus = {}
    local bottom_bus_idx = 2
    local used_directions = {
        [EntityDirection.UP] = false,
        [EntityDirection.DOWN] = false,
        [EntityDirection.LEFT] = false,
        [EntityDirection.RIGHT] = false,
    }

    local function process_fluid(fluids, connections, type)
        local index = 1
        for _, fluid in ipairs(fluids) do
            if fluid.fluidbox_index then
                index = fluid.fluidbox_index
            end
            local connection = connections[index]
            local direction = connection.direction
            local pos = connection.position
            -- first case: just follow the direction
            CoordTable.set(data, pos.x, pos.y,
                ActionPair.new(Entity.new(full_config.pipe_underground_name, Reverse_direction(connection.direction), {},
                    {})))
            local distance
            local distance2
            local direction2
            used_directions[direction] = true
            if direction == EntityDirection.UP then
                distance = top_bus_idx
                table.insert(top_bus, { fluid = fluid.name, type = type, loc = -top_bus_idx - 2, index = index })
                top_bus_idx = top_bus_idx + 1
            elseif direction == EntityDirection.DOWN then
                distance = bottom_bus_idx
                table.insert(bottom_bus,
                    { fluid = fluid.name, type = type, loc = machine.tile_height + bottom_bus_idx + 1, index = index })
                bottom_bus_idx = bottom_bus_idx + 1
            elseif direction == EntityDirection.LEFT then
                if type == PortType.FLUID_INPUT then -- input
                    distance = left_down_idx
                    table.insert(bottom_bus,
                        {
                            fluid = fluid.name,
                            type = PortType.FLUID_INPUT,
                            loc = machine.tile_height + bottom_bus_idx + 1,
                            index = index
                        })
                    left_down_idx = left_down_idx + 1
                    distance2 = 0 --TODO
                    bottom_bus_idx = bottom_bus_idx + 1
                    direction2 = EntityDirection.DOWN
                else
                    distance = left_up_idx
                    table.insert(top_bus,
                        { fluid = fluid.name, type = PortType.FLUID_OUTPUT, loc = -top_bus_idx - 2, index = index })
                    left_up_idx = left_up_idx + 1
                    distance2 = 0 -- TODO
                    top_bus_idx = top_bus_idx + 1
                    direction2 = EntityDirection.UP
                end
            else
                if type == PortType.FLUID_INPUT then -- input
                    distance = right_down_idx
                    table.insert(bottom_bus,
                        {
                            fluid = fluid.name,
                            type = PortType.FLUID_INPUT,
                            loc = machine.tile_height + bottom_bus_idx + 1,
                            index = index
                        })
                    right_down_idx = right_down_idx + 1
                    distance2 = 0 --TODO
                    bottom_bus_idx = bottom_bus_idx + 1
                    direction2 = EntityDirection.DOWN
                else
                    distance = right_up_idx
                    table.insert(top_bus,
                        { fluid = fluid.name, type = PortType.FLUID_OUTPUT, loc = -top_bus_idx - 2, index = index })
                    right_up_idx = right_up_idx + 1
                    distance2 = 0
                    top_bus_idx = top_bus_idx + 1
                    direction2 = EntityDirection.UP
                end
            end
            for i = 1, distance do
                pos = Follow_direction(connection.direction, pos)
            end
            direction = connection.direction
            if distance2 then
                error("TODO: check this: Distance 2 " .. distance2)
                CoordTable.set(data, pos.x, pos.y,
                    ActionPair.new(Entity.new(full_config.pipe_underground_name, connection.direction, {}, {})))
                pos = Follow_direction(direction, pos)
                -- place a pipe at this location
                CoordTable.set(data, pos.x, pos.y,
                    ActionPair.new(Entity.new(full_config.pipe_item_name, direction, {}, {})))
                -- change direction
                pos = Follow_direction(direction2, pos)
                CoordTable.set(data, pos.x, pos.y,
                    ActionPair.new(Entity.new(full_config.pipe_underground_name, Reverse_direction(direction), {}, {})))
                for i = 1, distance2 do
                    pos = Follow_direction(direction2, pos)
                end
                direction = direction2
            end
            -- now place the tap at the current location, with direction orthogonal to the one given
            CoordTable.set(data, pos.x, pos.y,
                ActionPair.new(Entity.new(full_config.pipe_underground_name, direction, {}, {})))
            pos = Follow_direction(direction, pos)
            CoordTable.set(data, pos.x, pos.y,
                ActionPair.new(Entity.new(full_config.pipe_item_name, direction, {}, {})))

            if direction == EntityDirection.UP or direction == EntityDirection.DOWN then
                direction = EntityDirection.LEFT
            else
                direction = EntityDirection.RIGHT
            end
            local pos1 = Follow_direction(direction, pos)
            local pos2 = Follow_direction(Reverse_direction(direction), pos)
            CoordTable.set(data, pos1.x, pos1.y,
                ActionPair.new(Entity.new(full_config.pipe_underground_name, Reverse_direction(direction), {}, {})))
            CoordTable.set(data, pos2.x, pos2.y,
                ActionPair.new(Entity.new(full_config.pipe_underground_name, direction, {}, {})))
        end
    end
    process_fluid(fluid_inputs, inputs, PortType.FLUID_INPUT)
    process_fluid(fluid_outputs, outputs, PortType.FLUID_OUTPUT)

    local ports = {}
    for _, data in ipairs(top_bus) do
        table.insert(ports, Port.new(data.index, data.loc, data.type, { data.fluid }, LanePriority.NORMAL))
    end
    for _, data in ipairs(bottom_bus) do
        table.insert(ports, Port.new(data.index, data.loc, data.type, { data.fluid }, LanePriority.NORMAL))
    end

    local final_amount
    if primary_output and primary_output.item_type ~= ItemType.FLUID then
        final_amount = Logistic.calculate_final_amount(full_config, primary_output, is_final, recipe,
            timescale, machine.crafting_speed)
    end

    data = Logistic.add_chests(data, full_config, used_directions, free_directions, item_inputs, primary_output,
        byproducts, final_amount)


    ---@type Diagram
    local diagram = Primitive.new(data)

    -- set the recipe and modules here
    local transform = Transformation.map(Transformations.set_assembling_machine_details(recipe_info, full_config))
    diagram = diagram:act(transform)

    return diagram, ports
end

---Create barrelling machines
---@param ports Port[]
---@param full_config FullConfig
---@return Diagram
function LocalFluidBus.create_barrelling_machines(ports, full_config)
    local data = CoordTable.new()

    ---@type Port[]
    local sorted_ports = {}
    for _, port in ipairs(ports) do table.insert(sorted_ports, port) end
    table.sort(sorted_ports, function(a, b) return a.coord < b.coord end)

    -- create barrellers, starting at -2, max coord + 2, going left.  Record hooking up location
    local position = { x = -2 - 3, y = -1 }
    local connections = {}
    for _, port in ipairs(sorted_ports) do
        local barrel_recipe
        local entity_direction = EntityDirection.UP
        if port.port_type == PortType.FLUID_INPUT then
            barrel_recipe = full_config.game_data.barrel_lookup[port.items[1]].from_barrel
            entity_direction = Reverse_direction(entity_direction)
        else
            barrel_recipe = full_config.game_data.barrel_lookup[port.items[1]].to_barrel
        end
        if not barrel_recipe then
            error(string.format("Cannot find barrel/unbarrel recipe for %s", port.items[1]))
        end

        local chest_direction = EntityDirection.DOWN
        local chest_offset = 3
        local pipe_offset = -1

        if port.coord > 0 then
            entity_direction = Reverse_direction(entity_direction)
            chest_direction = EntityDirection.UP
            chest_offset = -1
            pipe_offset = 3
        end

        CoordTable.set(data, position.x, position.y,
            ActionPair.new(Entity.new(full_config.barrelling_machine, entity_direction, {},
                { recipe = barrel_recipe })))
        Set_delete_entities(data, full_config.barrelling_machine, position.x, position.y, entity_direction,
            full_config.game_data.size_data)

        -- create logistic chests
        if port.port_type == PortType.FLUID_INPUT then
            Logistic.create_input_fluid_chests(data, full_config, port.items[1],
                { x = position.x, y = position.y + chest_offset },
                chest_direction, { x = position.x + 1, y = position.y + chest_offset }, chest_direction)
        else
            Logistic.create_output_fluid_chests(data, full_config, port.items[1],
                { x = position.x, y = position.y + chest_offset },
                chest_direction, { x = position.x + 1, y = position.y + chest_offset }, chest_direction)
        end
        CoordTable.set(data, position.x + 2, position.y + chest_offset,
            ActionPair.new(Entity.new(full_config.pole, EntityDirection.UP, {}, {})))

        table.insert(connections, { x = position.x + 1, y = position.y + pipe_offset, coord = port.coord })
        position = Follow_direction(EntityDirection.LEFT, position)
        position = Follow_direction(EntityDirection.LEFT, position)
        position = Follow_direction(EntityDirection.LEFT, position)
    end

    -- now hook up connections, go down, then right
    for _, connection in ipairs(connections) do
        local direction = EntityDirection.DOWN
        local x_offset = 1
        if connection.coord > 0 then
            direction = EntityDirection.UP
            x_offset = -1
        end
        CoordTable.set(data, connection.x, connection.y,
            ActionPair.new(Entity.new(full_config.pipe_underground_name, direction, {}, {})))
        CoordTable.set(data, connection.x, connection.coord,
            ActionPair.new(Entity.new(full_config.pipe_item_name, direction, {}, {})))
        CoordTable.set(data, connection.x, connection.coord + x_offset,
            ActionPair.new(Entity.new(full_config.pipe_underground_name, Reverse_direction(direction), {}, {})))
        CoordTable.set(data, connection.x + 1, connection.coord,
            ActionPair.new(Entity.new(full_config.pipe_underground_name, EntityDirection.LEFT, {}, {})))
        CoordTable.set(data, -2, connection.coord,
            ActionPair.new(Entity.new(full_config.pipe_underground_name, EntityDirection.RIGHT, {}, {})))
        CoordTable.set(data, -1, connection.coord,
            ActionPair.new(Entity.new(full_config.pipe_underground_name, EntityDirection.LEFT, {}, {})))

        -- -- if the gap going up is too big add extra pipes
        -- if math.abs(connection.coord - connection.y) > full_config.game_data.entities[full_config.pipe_underground_name].max_underground_distance then
        --     local mid = math.floor((connection.coord + connection.y) / 2)
        --     CoordTable.set(data, connection.x, mid,
        --         ActionPair.new(Entity.new(full_config.pipe_underground_name, EntityDirection.DOWN, {}, {})))
        --     CoordTable.set(data, connection.x, mid + 1,
        --         ActionPair.new(Entity.new(full_config.pipe_underground_name, EntityDirection.UP, {}, {})))
        -- end
    end


    local diagram = Primitive.new(data)
    return diagram
end

---Create a LocalFluidBus Network from a FullRecipe
---@param full_recipe FullRecipe
---@param config FullConfig
---@return LocalFluidBus
function LocalFluidBus.from_full_recipe(full_recipe, config)
    local final_outputs = full_recipe:get_outputs()
    local diagram = Empty.new()
    for _idx, recipe in ipairs(full_recipe.recipes) do
        local primary_output = recipe.recipe.outputs[1]
        local item_inputs = Array_filter(recipe.recipe.inputs,
            function(item) return item.item_type == ItemType.ITEM or item.item_type == ItemType.FUEL end)
        local fluid_inputs = Array_filter(recipe.recipe.inputs,
            function(item) return item.item_type == ItemType.FLUID end)
        local fluid_outputs = Array_filter(recipe.recipe.outputs,
            function(item) return item.item_type == ItemType.FLUID end)
        local machine_diagram, ports = LocalFluidBus.create_machine(recipe.machine_name, recipe, config,
            full_recipe.timescale, item_inputs, primary_output, final_outputs[primary_output.name], {}, fluid_inputs,
            fluid_outputs)
        local port_diagram = LocalFluidBus.create_barrelling_machines(ports, config)
        local row_diagram = Empty.new()
        for _ = 1, math.ceil(recipe.machine_count) do
            row_diagram = Beside(row_diagram, machine_diagram, Direction.RIGHT)
        end
        row_diagram = Beside(row_diagram, port_diagram, Direction.LEFT)
        diagram = Beside(diagram, row_diagram, Direction.DOWN)
    end

    return LocalFluidBus.new(diagram, config)
end

function LocalFluidBus:to_blueprint()
    local compiled, regions = self.diagram:compile()
    return Primitives_to_blueprint(
        compiled,
        regions,
        { Optimizations.optimize_underground_pipes },
        { PostProcessing.connect_electrical_grids },
        self.config
    )
end

---Create a LocalFluidBus Template
---@param recipe RecipeInfo
---@param full_config FullConfig
---@param is_final? boolean
---@param timescale int
---@return Template
function LocalFluidBus.create_template(recipe, full_config, is_final, timescale)
    local primary_output = recipe.recipe.outputs[1]
    local item_inputs = Array_filter(recipe.recipe.inputs,
        function(item) return item.item_type == ItemType.ITEM or item.item_type == ItemType.FUEL end)
    local fluid_inputs = Array_filter(recipe.recipe.inputs,
        function(item) return item.item_type == ItemType.FLUID end)
    local fluid_outputs = Array_filter(recipe.recipe.outputs,
        function(item) return item.item_type == ItemType.FLUID end)
    local machine_diagram, ports = LocalFluidBus.create_machine(recipe.machine_name, recipe, full_config, timescale,
        item_inputs, primary_output, is_final, {}, fluid_inputs, fluid_outputs)
    local data = CoordTable.new()
    for _, port in ipairs(ports) do
        CoordTable.set(data, 0, port.coord,
            ActionPair.new(Entity.new(full_config.pipe_underground_name, EntityDirection.LEFT, {}, {})))
    end
    if #ports == 0 then
        CoordTable.set(data, 0, 0, ActionPair.new(Entity.new(full_config.pole, EntityDirection.UP, {}, {})))
    end
    local template_diagram = Primitive.new(data)
    local tags = {}
    if #fluid_inputs > 0 or #fluid_outputs > 0 then
        MetadataTags["envelope-up"].set_tag(tags, 2)
        MetadataTags["envelope-down"].set_tag(tags, 2)
    end
    return Template.new("LocalFluidBus-" .. recipe.recipe.name, template_diagram, { Machine.new(machine_diagram, 1) },
        ports, tags)
end
