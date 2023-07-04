--- create a logistic network

---@class Logistic : BaseClass
---@field diagram Diagram
---@field config FullConfig
Logistic = InheritsFrom(nil)

---Create a new Logistic object
---@param diagram Diagram
---@param config FullConfig
---@return Logistic
function Logistic.new(diagram, config)
    local self = Logistic:create()
    self.diagram = diagram
    self.config = config
    return self
end

---Given x, y relative to the origin find the direction they are facing
---@param x int
---@param y int
---@return EntityDirection?
local function pipe_connection_to_direction(x, y)
    if x > y then
        if x > -y then
            return EntityDirection.RIGHT
        elseif x < -y then
            return EntityDirection.UP
        end
    elseif x < y then
        if x > -y then
            return EntityDirection.DOWN
        elseif x < -y then
            return EntityDirection.LEFT
        end
    end
end

---Calculate fluidbox info about an entity
---@param machine_name string
---@param full_config FullConfig
---@param entity_direction? EntityDirection direction of entity
---@return {position:{x:int,y:int},direction:EntityDirection,index:int}[] inputs
---@return {position:{x:int,y:int},direction:EntityDirection,index:int}[] outputs
---@return {position:{x:int,y:int},direction:EntityDirection,index:int}[] input_outputs
---@return table<EntityDirection,{x:int,y:int}[]> free directions
function Logistic.calculate_fluidbox_info(machine_name, full_config, entity_direction)
    if entity_direction == nil then entity_direction = EntityDirection.UP end
    local machine_data = full_config.game_data.entities[machine_name]
    local inputs = {}
    local outputs = {}
    local input_outputs = {}

    local fluidboxes = {}
    local direction_arrays = {
        [EntityDirection.UP] = {},
        [EntityDirection.DOWN] = {},
        [EntityDirection.LEFT] = {},
        [EntityDirection.RIGHT] = {},
    }
    local free_directions = {
        [EntityDirection.UP] = {},
        [EntityDirection.DOWN] = {},
        [EntityDirection.LEFT] = {},
        [EntityDirection.RIGHT] = {},
    }
    for _, value in ipairs(machine_data.fluidbox_prototypes) do
        table.insert(fluidboxes, value)
    end
    table.sort(fluidboxes, function(a, b) return a.index < b.index end)

    for _, value in ipairs(fluidboxes) do
        -- find out what direction it is
        local position = Copy(value.pipe_connections[1].positions[(entity_direction / 2) + 1])
        local direction = pipe_connection_to_direction(position.x, position.y)
        if direction == nil then
            error(string.format("Could not work out direction of pipe conection (%d, %d) for %s", position.x, position.y,
                machine_name))
        end
        -- note: data will be modified later
        local data = { position = position, direction = direction }
        table.insert(direction_arrays[direction], data)

        -- find out what type it is
        if value.production_type == "input" then
            table.insert(inputs, data)
        elseif value.production_type == "output" then
            table.insert(outputs, data)
        elseif value.production_type == "input-output" then
            table.insert(input_outputs, data)
        end
    end

    -- now for each direction, sort the connections by x and y, then color even or odd
    -- this is so the barrelers, which are 3x3, don't collide with each, since the connections have only a single space
    for direction, connections in pairs(direction_arrays) do
        table.sort(connections,
            function(a, b)
                if a.position.x == b.position.x then
                    return a.position.y < b.position.y
                else
                    return a
                        .position.x < b.position.x
                end
            end)
        local idx = 1
        local used_x_values = {}
        local used_y_values = {}

        for _, entry in ipairs(connections) do
            entry.index = idx
            idx = idx + 1
            -- now also correct their coordinates
            entry.position.x = math.floor(entry.position.x + machine_data.tile_width / 2 + 0.1)
            entry.position.y = math.floor(entry.position.y + machine_data.tile_height / 2 + 0.1)
            used_x_values[entry.position.x] = true
            used_y_values[entry.position.y] = true
        end
        if direction == EntityDirection.UP then
            for i = 0, machine_data.tile_width - 1 do
                if used_x_values[i] == nil then
                    table.insert(free_directions[direction], { x = i, y = -1 })
                end
            end
        elseif direction == EntityDirection.DOWN then
            for i = 0, machine_data.tile_width - 1 do
                if used_x_values[i] == nil then
                    table.insert(free_directions[direction], { x = i, y = machine_data.tile_height })
                end
            end
        elseif direction == EntityDirection.RIGHT then
            for i = 0, machine_data.tile_height - 1 do
                if used_y_values[i] == nil then
                    table.insert(free_directions[direction], { x = machine_data.tile_width, y = i })
                end
            end
        else
            for i = 0, machine_data.tile_height - 1 do
                if used_y_values[i] == nil then
                    table.insert(free_directions[direction], { x = -1, y = i })
                end
            end
        end
    end
    return inputs, outputs, input_outputs, free_directions
end

function Logistic.create_input_fluid_chests(data, full_config, fluid_name, position1, direction1, position2, direction2)
    CoordTable.set(data, position1.x, position1.y,
        ActionPair.new(Entity.new(full_config.inserter, direction1, {}, {})))
    position1 = Follow_direction(direction1, position1)
    local recipe = full_config.game_data.recipes[full_config.game_data.barrel_lookup[fluid_name].from_barrel]
    local request_filters = {}
    local index = 1
    for _, item in ipairs(recipe.inputs) do
        table.insert(request_filters,
            {
                index = index,
                name = item.name,
                count = full_config.logistic_input_multiplier * item:get_average_amount()
            })
        index = index + 1
    end
    CoordTable.set(data, position1.x, position1.y,
        ActionPair.new(Entity.new(full_config.logistic_input, direction1, {}, { request_filters = request_filters })))
    CoordTable.set(data, position2.x, position2.y,
        ActionPair.new(Entity.new(full_config.inserter, Reverse_direction(direction2), {}, {})))
    position2 = Follow_direction(direction2, position2)
    CoordTable.set(data, position2.x, position2.y,
        ActionPair.new(Entity.new(full_config.logistic_byproduct, direction2, {}, {})))
end

function Logistic.create_output_fluid_chests(data, full_config, fluid_name, position1, direction1, position2, direction2)
    CoordTable.set(data, position1.x, position1.y,
        ActionPair.new(Entity.new(full_config.inserter, direction1, {}, {})))
    position1 = Follow_direction(direction1, position1)
    local recipe = full_config.game_data.recipes[full_config.game_data.barrel_lookup[fluid_name].from_barrel]
    local request_filters = {}
    local index = 1
    for _, item in ipairs(recipe.inputs) do
        table.insert(request_filters,
            {
                index = index,
                name = item.name,
                count = full_config.logistic_input_multiplier * item:get_average_amount()
            })
        index = index + 1
    end
    CoordTable.set(data, position1.x, position1.y,
        ActionPair.new(Entity.new(full_config.logistic_input, direction1, {}, { request_filters = request_filters })))

    CoordTable.set(data, position2.x, position2.y,
        ActionPair.new(Entity.new(full_config.inserter, Reverse_direction(direction2), {},
            {})))
    position2 = Follow_direction(direction2, position2)

    local logistic_chest_entity = full_config.game_data.entities[full_config.logistic_output]
    -- TODO work proper output amounts
    local args = { bar = 1 }

    if logistic_chest_entity.logistic_mode == "storage" then
        -- set a request filter to only these entities
        args.request_filters = {
            { index = 1, name = full_config.game_data.barrel_lookup[fluid_name].barrel_name, count = 0 } }
    end
    CoordTable.set(data, position2.x, position2.y,
        ActionPair.new(Entity.new(full_config.logistic_output, direction2, {}, args)))
end

---Add logistic chests
---@param data table
---@param full_config FullConfig
---@param used_directions EntityDirection[]
---@param free_directions any
---@param item_inputs IngredientItem[]
---@param item_output? IngredientItem
---@param item_byproducts IngredientItem[]
---@param final_amount? int
---@return table
function Logistic.add_chests(data, full_config, used_directions, free_directions, item_inputs, item_output,
                             item_byproducts, final_amount)
    -- find some empty spots for the logistic chests
    local empty_spots = {}
    local empty_spots_remaining = {}
    for direction, used in pairs(used_directions) do
        for _, loc in ipairs(free_directions[direction]) do
            if used then
                table.insert(empty_spots, { direction = direction, position = loc })
            else
                table.insert(empty_spots_remaining, { direction = direction, position = loc })
            end
        end
    end
    -- now remaining spots
    for _, spot in ipairs(empty_spots_remaining) do
        table.insert(empty_spots, spot)
    end

    local current_position_index = 1

    -- now create logistic chests
    if #item_inputs > 0 then
        -- create request filters
        local request_filters = {}
        local index = 1
        local spot = empty_spots[current_position_index]
        current_position_index = current_position_index + 1
        local position = spot.position
        for _, item in ipairs(item_inputs) do
            table.insert(request_filters,
                {
                    index = index,
                    name = item.name,
                    count = full_config.logistic_input_multiplier * item:get_average_amount()
                })
            index = index + 1
        end
        CoordTable.set(data, position.x, position.y,
            ActionPair.new(Entity.new(full_config.inserter, spot.direction, {}, {})))
        local position = Follow_direction(spot.direction, spot.position)
        CoordTable.set(data, position.x, position.y,
            ActionPair.new(Entity.new(full_config.logistic_input, Reverse_direction(spot.direction), {},
                { request_filters = request_filters })))
    end

    -- create primary output chest
    if item_output and item_output.item_type ~= ItemType.FLUID then
        local spot = empty_spots[current_position_index]
        current_position_index = current_position_index + 1
        local position = spot.position
        local chest_args = {}
        local inserter_args = {}
        if full_config.logistic_output_circuit_controlled then
            -- TODO check is this is a final output or not
            inserter_args.connections = { ["1"] = { red = { { relative_x = 0, relative_y = -1 } } } }
            chest_args.connections = { ["1"] = { red = { { relative_x = 0, relative_y = 1 } } } }

            inserter_args.control_behavior = {
                circuit_condition = {
                    first_signal = {
                        type = "item",
                        name = item_output.name
                    },
                    constant = final_amount,
                    comparator = "≤",
                }
            }
        else
            -- calculate the bar
            local stack_size = full_config.game_data.items[item_output.name].stack_size
            -- TODO is this a final output or just a normal output
            chest_args.bar = math.max(1, math.ceil(final_amount / stack_size))
        end
        local logistic_chest_entity = full_config.game_data.entities[full_config.logistic_output]
        if logistic_chest_entity.logistic_mode == "storage" then
            -- set a request filter to only these entities
            chest_args.request_filters = { { index = 1, name = item_output.name, count = 0 } }
        end
        if item_byproducts == nil or #item_byproducts == 0 then
            CoordTable.set(data, position.x, position.y,
                ActionPair.new(Entity.new(full_config.inserter, Reverse_direction(spot.direction), {}, inserter_args)))
        else
            -- need a filter
            inserter_args.filters = { { index = 1, name = item_output.name } }
            CoordTable.set(data, position.x, position.y,
                ActionPair.new(Entity.new(full_config.filter_inserter, Reverse_direction(spot.direction), {},
                    inserter_args)))
        end
        position = Follow_direction(spot.direction, position)
        CoordTable.set(data, position.x, position.y,
            ActionPair.new(Entity.new(full_config.logistic_output, spot.direction, {}, chest_args)))
    end

    -- create byproducts
    local remaining_filter_spots = full_config.game_data.entities[full_config.filter_inserter].filter_count
    local spot = empty_spots[current_position_index]
    local index = 1
    local filter = {}
    local last_item_name
    if item_byproducts then
        last_item_name = item_byproducts[#item_byproducts]
    end
    for _, item in ipairs(item_byproducts or {}) do
        table.insert(filter, { name = item.name, index = index })
        index = index + 1
        remaining_filter_spots = remaining_filter_spots - 1
        if remaining_filter_spots == 0 or item.name == last_item_name then
            local position = spot.position
            CoordTable.set(data, position.x, position.y,
                ActionPair.new(Entity.new(full_config.filter_inserter, Reverse_direction(spot.direction), {},
                    { filters = filter })))
            position = Follow_direction(spot.direction, position)
            CoordTable.set(data, position.x, position.y,
                ActionPair.new(Entity.new(full_config.logistic_byproduct, spot.direction, {}, {})))

            remaining_filter_spots = full_config.game_data.entities[full_config.filter_inserter].filter_count
            current_position_index = current_position_index + 1
            spot = empty_spots[current_position_index]
            index = 1
            filter = {}
        end
    end


    -- add pole
    spot = empty_spots[current_position_index]
    current_position_index = current_position_index + 1
    CoordTable.set(data, spot.position.x, spot.position.y,
        ActionPair.new(Entity.new(full_config.pole, EntityDirection.UP, {}, {})))
    return data
end

---Calculate the final amount required for a recipe
---@param full_config FullConfig
---@param item_output IngredientItem
---@param is_final? boolean
---@param recipe? Recipe
---@param timescale int
---@param crafting_speed float
---@return integer
function Logistic.calculate_final_amount(full_config, item_output, is_final, recipe, timescale, crafting_speed)
    local final_amount
    if is_final then
        local energy = 1
        if recipe then energy = recipe.energy end -- may have an imposotor recipe
        -- final outputs get a lot more produced, logistic_final_output_multiplier timescales worth of output
        final_amount = full_config.logistic_final_output_multiplier * item_output:get_average_amount() *
            timescale / energy * crafting_speed
    else
        final_amount = full_config.logistic_output_multiplier * item_output:get_average_amount()
    end
    final_amount = math.max(1, math.ceil(final_amount))
    return final_amount
end

---Create a diagram for a single machine
---@param name string entity name
---@param full_config FullConfig
---@param recipe_info RecipeInfo
---@param full_recipe FullRecipe
---@param item_inputs? IngredientItem[]
---@param item_output? IngredientItem
---@param is_final? boolean
---@param item_byproducts? IngredientItem[]
---@param fluid_inputs? IngredientItem[]
---@param fluid_outputs? IngredientItem[]
---@return Diagram
function Logistic.create_machine(name, recipe_info, full_config, full_recipe, item_inputs, item_output, is_final,
                                 item_byproducts, fluid_inputs, fluid_outputs)
    if item_inputs == nil then item_inputs = {} end
    if fluid_inputs == nil then fluid_inputs = {} end
    if item_output == nil then item_output = {} end
    if item_byproducts == nil then item_byproducts = {} end
    if fluid_outputs == nil then fluid_outputs = {} end
    local inputs, outputs, input_outputs, free_directions = Logistic.calculate_fluidbox_info(name, full_config)
    local data = CoordTable.new()
    local direction = EntityDirection.UP
    local entity = Entity.new(name, direction, {}, {})
    local recipe = full_config.game_data.recipes[recipe_info.recipe.name]

    local machine = full_config.game_data.entities[recipe_info.machine_name]
    EntityTags.machine.set_tag(entity, true)
    CoordTable.set(data, 0, 0, ActionPair.new(entity))
    Set_delete_entities(data, name, 0, 0, direction, full_config.game_data.size_data)

    local used_directions = {
        [EntityDirection.UP] = false,
        [EntityDirection.DOWN] = false,
        [EntityDirection.LEFT] = false,
        [EntityDirection.RIGHT] = false,
    }

    local function process_fluid(index, fluid, is_input, fluidboxes)
        if fluid.fluidbox_index then
            index = fluid.fluidbox_index
        end
        local connection = fluidboxes[index]
        used_directions[connection.direction] = true
        local pos = connection.position
        -- place a pipe here
        CoordTable.set(data, pos.x, pos.y,
            ActionPair.new(Entity.new(full_config.pipe_underground_name, Reverse_direction(connection.direction), {}, {})))
        local count = 1 + 2
        if connection.index % 2 == 0 then count = 4 + 2 end
        for _ = 1, count do
            pos = Follow_direction(connection.direction, pos)
        end
        CoordTable.set(data, pos.x, pos.y,
            ActionPair.new(Entity.new(full_config.pipe_underground_name, connection.direction, {}, {})))
        pos = Follow_direction(connection.direction, pos)
        pos = Follow_direction(connection.direction, pos)
        -- we a now at the center of the barreler
        local barrel_recipe
        if is_input then
            barrel_recipe = full_config.game_data.barrel_lookup[fluid.name].from_barrel
        else
            barrel_recipe = full_config.game_data.barrel_lookup[fluid.name].to_barrel
        end
        if not barrel_recipe then
            error(string.format("Cannot find barrel/unbarrel recipe for %s", fluid))
        end
        local entity_direction = connection.direction
        if not is_input then
            entity_direction = Reverse_direction(entity_direction)
            if not entity_direction then error("entity direction is nil") end
        end
        CoordTable.set(data, pos.x - 1, pos.y - 1,
            ActionPair.new(Entity.new(full_config.barrelling_machine, entity_direction, {},
                { recipe = barrel_recipe })))
        Set_delete_entities(data, full_config.barrelling_machine, pos.x - 1, pos.y - 1, entity_direction,
            full_config.game_data.size_data)
        -- now create chests - to avoid issues with unbounded sizes even follows direction
        -- odd has one follow the direction, the other doing the opposite, trying between two possible locations
        if connection.index % 2 == 0 then
            pos = Follow_direction(connection.direction, pos)
            pos = Follow_direction(connection.direction, pos)
            local save_pos = Copy(pos)
            local other_pos = Copy(pos)
            if connection.direction == EntityDirection.UP or connection.direction == EntityDirection.DOWN then
                save_pos.x = save_pos.x + 1
                other_pos.x = other_pos.x - 1
            else
                save_pos.y = save_pos.y + 1
                other_pos.y = other_pos.y - 1
            end
            if is_input then
                Logistic.create_input_fluid_chests(data, full_config, fluid.name, pos, connection.direction, save_pos,
                    connection.direction)
            else
                Logistic.create_output_fluid_chests(data, full_config, fluid.name, pos, connection.direction, save_pos,
                    connection.direction)
            end
            local pole_pos = Copy(pos)
            pole_pos = Follow_direction(Reverse_direction(connection.direction), pole_pos)
            pole_pos = Follow_direction(Reverse_direction(connection.direction), pole_pos)
            if connection.direction == EntityDirection.UP or connection.direction == EntityDirection.DOWN then
                pole_pos.x = pos.x - 2
            else
                pole_pos.y = pos.y - 2
            end
            CoordTable.set(data, pole_pos.x, pole_pos.y, ActionPair.new(Entity.new(full_config.pole, 0, {}, {})))
        else
            local pos3 = Copy(pos)
            local rev_dir = Reverse_direction(connection.direction)
            pos3 = Follow_direction(connection.direction, pos3)
            pos3 = Follow_direction(connection.direction, pos3)
            pos = Follow_direction(rev_dir, pos)
            pos = Follow_direction(rev_dir, pos)

            local pos1 = Copy(pos)
            local pos2 = Copy(pos)
            if connection.direction == EntityDirection.UP or connection.direction == EntityDirection.DOWN then
                pos1.x = pos1.x + 1
                pos2.x = pos2.x - 1
            else
                pos1.y = pos1.y + 1
                pos2.y = pos2.y - 1
            end
            if is_input then
                Logistic.create_input_fluid_chests(data, full_config, fluid.name, pos1, rev_dir, pos2,
                    rev_dir)
            else
                Logistic.create_output_fluid_chests(data, full_config, fluid.name, pos1, rev_dir, pos2,
                    rev_dir)
                pos3 = Follow_direction(connection.direction, pos3)
                pos3 = Follow_direction(connection.direction, pos3)
                CoordTable.set(data, pos3.x, pos3.y, ActionPair.new(Entity.new(full_config.pole, 0, {}, {})))
            end
            pos = Follow_direction(rev_dir, pos)
            CoordTable.set(data, pos.x, pos.y, ActionPair.new(Entity.new(full_config.pole, 0, {}, {})))
        end
    end

    -- fluid handling first
    for index, fluid in ipairs(fluid_inputs) do
        process_fluid(index, fluid, true, inputs)
    end
    for index, fluid in ipairs(fluid_outputs) do
        process_fluid(index, fluid, false, outputs)
    end

    local final_amount
    if item_output and item_output.item_type ~= ItemType.FLUID then
        final_amount = Logistic.calculate_final_amount(full_config, item_output, is_final, recipe, full_recipe.timescale,
            machine.crafting_speed)
    end

    data = Logistic.add_chests(data, full_config, used_directions, free_directions, item_inputs, item_output,
        item_byproducts, final_amount)

    ---@type Diagram
    local diagram = Primitive.new(data)

    -- set the recipe and modules here
    local transform = Transformation.map(Transformations.set_assembling_machine_details(recipe_info, full_config))
    diagram = diagram:act(transform)
    return diagram
end

---Pack all the machines
---@param machines {diagram:Diagram, width: int, height: int}[]
---@param config FullConfig
---@return Diagram
local function pack(machines, config)
    local full_width = config.logistic_width
    local height = 0

    -- create a roboport diagram
    local roboport_data = CoordTable.new()
    CoordTable.set(roboport_data, 0, 0,
        ActionPair.new(Entity.new(config.logistic_roboport, EntityDirection.UP, {}, {})))
    Set_delete_entities(roboport_data, config.logistic_roboport, 0, 0, EntityDirection.UP, config.game_data.size_data)
    local roboport = Primitive.new(roboport_data)
    local roboport_envelope = roboport:envelope()
    if roboport_envelope == nil then error("Roboport envelope is nil") end
    local roboport_width = roboport_envelope.left + roboport_envelope.right + 1

    -- sort the machines, first by height, then by width
    table.sort(machines, function(a, b)
        if a.height == b.height then
            return a.width > b.width
        else
            return a.height > b.height
        end
    end)
    local rows = {}
    local current_row = {}
    local remaining_width = full_width
    local max_height = 0
    local next_roboport = -2
    for _, machine in ipairs(machines) do
        -- put in a roboport if we are almost halfway though the row, and a roboport is required
        if height >= next_roboport and remaining_width - machine.width <= 25 then
            table.insert(current_row, Translate(math.floor((25 - remaining_width) / 2.0), 0, roboport))
            next_roboport = next_roboport + 25
            remaining_width = remaining_width - roboport_width
        end
        if machine.width <= remaining_width then
            -- still room to fit this machine in
            table.insert(current_row, machine.diagram)
            remaining_width = remaining_width - machine.width
            max_height = math.max(max_height, machine.height)
        else
            -- no more room, so create a new row
            table.insert(rows, current_row)
            current_row = {}
            remaining_width = full_width
            height = height + max_height
            max_height = 0
        end
    end
    if #current_row > 0 then
        table.insert(rows, current_row)
    end

    -- now we print them out
    local diagram = Empty.new()
    for _, row in ipairs(rows) do
        local row_diagram = Empty.new()
        for _, machine in ipairs(row) do
            row_diagram = Beside(row_diagram, machine, Direction.RIGHT)
        end
        diagram = Beside(diagram, row_diagram, Direction.UP)
    end

    return diagram
end

---Create a Logistic Network from a FullRecipe
---@param full_recipe FullRecipe
---@param config FullConfig
---@return Logistic
function Logistic.from_full_recipe(full_recipe, config)
    local final_outputs = full_recipe:get_outputs()
    ---@type {diagram:Diagram, width: int, height: int}[]
    local all_machines = {}
    for _idx, recipe in ipairs(full_recipe.recipes) do
        local primary_output = recipe.recipe.outputs[1]
        local item_inputs = Array_filter(recipe.recipe.inputs,
            function(item) return item.item_type == ItemType.ITEM or item.item_type == ItemType.FUEL end)
        local fluid_inputs = Array_filter(recipe.recipe.inputs,
            function(item) return item.item_type == ItemType.FLUID end)
        local fluid_outputs = Array_filter(recipe.recipe.outputs,
            function(item) return item.item_type == ItemType.FLUID end)
        local machine_diagram = Logistic.create_machine(recipe.machine_name, recipe, config, full_recipe,
            item_inputs, primary_output, final_outputs[primary_output.name], {}, fluid_inputs, fluid_outputs)

        -- get the envelope to calculate width and ehight
        local envelope = machine_diagram:envelope()
        if not envelope then
            error(string.format("Envelope failed for recipe %s", recipe.recipe.name))
        end
        local width = envelope.left + envelope.right + 1
        local height = envelope.up + envelope.down + 1

        for _ = 1, math.ceil(recipe.machine_count) do
            table.insert(all_machines,
                { diagram = Translate(envelope.left, envelope.down, machine_diagram), width = width, height = height })
        end
    end
    local diagram = pack(all_machines, config)
    return Logistic.new(diagram, config)
end

function Logistic:to_blueprint()
    local compiled, regions = self.diagram:compile()
    return Primitives_to_blueprint(
        compiled,
        regions,
        {}, -- no optimizations required at this stage
        { PostProcessing.connect_electrical_grids },
        self.config
    )
end
