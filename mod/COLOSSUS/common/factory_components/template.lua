-- Templates: these connect the crossbar to the assembly machines

require("common.factorio_objects.blueprint")
require("common.factory_components.bundle")
require("common.schematic.diagram")
require("common.factorio_objects.entity")
require("common.config.game_data")
require("common.factory_components.lane")
require("common.factory_components.tags")

require("common.utils.objects")
require("common.schematic.coord_table")
require("common.utils.utils")

---Type of coordinates
---@alias coord {x: int, y: int}

---Machine: Represents a diagram of machines
---@class Machine : BaseClass
---@field diagram Diagram
---@field count int number of machines in this diagram
Machine = InheritsFrom(nil)

---Create a new Machine
---@param diagram Diagram
---@param count int number of machines in this diagram
---@return Machine
function Machine.new(diagram, count)
    local self = Machine:create()
    self.diagram = diagram
    self.count = count
    return self
end

---Represents metadata to help choose a template
---@class TemplateMetadata: BaseClass
---@field custom_recipe? string
---@field buffer? string
---@field crafting_categories Set<string>
---@field item_inputs number
---@field item_outputs number
---@field item_loops number
---@field fluid_inputs number
---@field fluid_outputs number
---@field fluid_loops number
---@field num_machines? number maximum number of machines this supports
---@field priority? number
---@field machine_widths? Set<number>
---@field machine_heights? Set<number>
---@field mods? Set<string>
---@field envelope_up number
---@field envelope_down number
---@field machine? string
---@field fluidboxes? table<int,Fluidbox>
---@field uses_logistic_network? boolean
---@field is_generic? boolean
---@field fluidbox_generic? boolean Can handle any fluidbox configuration
---@field size_generic? boolean Can handle any size machine
TemplateMetadata = InheritsFrom(nil)

---Create a TemplateMetadata object from tags
---@param tags any
---@param game_data? GameData
---@return TemplateMetadata
function TemplateMetadata.from_tags(tags, game_data)
    local self = TemplateMetadata:create()
    self.custom_recipe = MetadataTags["custom-recipe"].get_tag(tags)
    self.buffer = MetadataTags["buffer"].get_tag(tags)
    self.crafting_categories = {}
    for _, category in pairs(Split_string(MetadataTags["crafting-categories"].get_tag(tags))) do
        self.crafting_categories[category] = true
    end
    self.item_inputs = tonumber(MetadataTags["item-inputs"].get_tag(tags)) or 0
    self.item_outputs = tonumber(MetadataTags["item-outputs"].get_tag(tags)) or 0
    self.item_loops = tonumber(MetadataTags["item-loops"].get_tag(tags)) or 0
    self.fluid_inputs = tonumber(MetadataTags["fluid-inputs"].get_tag(tags)) or 0
    self.fluid_outputs = tonumber(MetadataTags["fluid-outputs"].get_tag(tags)) or 0
    self.fluid_loops = tonumber(MetadataTags["fluid-loops"].get_tag(tags)) or 0
    self.priority = tonumber(MetadataTags["priority"].get_tag(tags)) or 0
    self.num_machines = tonumber(MetadataTags.machines.get_tag(tags)) or nil
    self.machine_heights = Set.map(tonumber, Set.from_array(MetadataTags["machine-heights"].get_tag_array(tags))) or nil
    self.machine_widths = Set.map(tonumber, Set.from_array(MetadataTags["machine-widths"].get_tag_array(tags))) or nil
    if Table_empty(self.machine_heights) then self.machine_heights = nil end
    if Table_empty(self.machine_widths) then self.machine_widths = nil end
    self.mods = Set.from_array(MetadataTags.mods.get_tag_array(tags)) or nil
    if Table_empty(self.mods) then self.mods = nil end
    self.envelope_down = tonumber(MetadataTags["envelope-down"].get_tag(tags)) or 0
    self.envelope_up = tonumber(MetadataTags["envelope-up"].get_tag(tags)) or 0
    self.machine = MetadataTags["machine-entity"].get_tag(tags)
    self.uses_logistic_network = (MetadataTags["uses-logistic-network"].get_tag(tags) ~= nil)

    if self.machine and game_data then
        -- now we want to load up the fluidboxes
        self.fluidboxes = {}
        local fluidboxes = game_data:get_fluidboxes_for_entity(self.machine)
        if fluidboxes then
            for _, fluidbox in ipairs(fluidboxes) do
                self.fluidboxes[fluidbox.index] = fluidbox
            end
        end
    end

    -- these cannot be set by tags, only by code
    self.is_generic = false
    self.size_generic = false
    self.fluidbox_generic = false

    return self
end

---Shift a template by an x, y ammount
---Generally used to fix template alignment problems
---Use the command /c __MOD-NAME__ Shift_template(global.players[1].templates[NUMBER])
---@param template any
---@param x int
---@param y int
function Shift_template(template, x, y)
    local blueprint_string = game.decode_string(template.blueprint)
    if blueprint_string == nil then
        game.print("Could not decode blueprint")
        return
    end
    local blueprint = game.json_to_table(blueprint_string)
    if blueprint == nil then
        game.print("Could not read blueprint JSON")
        return
    end
    for _, entity in pairs(blueprint.blueprint.entities) do
        if entity.position then entity.position.x = entity.position.x + x end
        if entity.position then entity.position.y = entity.position.y + y end
    end
    template.blueprint = game.encode_string(game.table_to_json(blueprint --[[@as table]]))
    local new_col_tags = {}
    for key, value in pairs(template.col_tags) do
        new_col_tags[key + x] = value
    end
    local new_row_tags = {}
    for key, value in pairs(template.row_tags) do
        new_row_tags[key + y] = value
    end
    template.col_tags = new_col_tags
    template.row_tags = new_row_tags
    game.print("Shifted template")
end

---Template: Represents a template
---@class Template : BaseClass
---@field name string
---@field template_diagram Diagram
---@field machines Machine[] assumes machine counts are decreasing
---@field tags? table<string,any> metadata for the template
---@field ports Port[]
Template = InheritsFrom(nil)

---Create a new Template
---@param name string
---@param template_diagram Diagram
---@param machines Machine[] assumes machine counts are decreasing
---@param ports Port[]
---@param tags? table<string,any>
---@return Template
function Template.new(name, template_diagram, machines, ports, tags)
    local self = Template:create()
    self.name = name
    self.template_diagram = template_diagram
    self.machines = machines
    self.ports = ports
    self.tags = tags
    return self
end

---Return a Diagram of machines that has at least as many machines
--- as count
---@param count int min number of machines required
---@return Diagram
function Template:get_machines(count)
    if Table_empty(self.machines) then
        return Empty.new()
    end
    local max_number = self.machines[1].count
    local base_count = math.floor(count / max_number)

    local left_over_count = count - base_count * max_number
    local final_diagram = Empty.new()

    if left_over_count > 0 then
        -- due to assumption this should give the best match
        for _, machine in ipairs(self.machines) do
            if machine.count >= left_over_count then
                final_diagram = machine.diagram
            end
        end
        final_diagram = final_diagram:act(Transformation.map(Transformations
            .remove_belt_ends))
    end

    local output = Empty.new()
    for i = 1, base_count do
        output = Beside(output, self.machines[1].diagram)
    end
    output = Beside(output, final_diagram)
    return output
end

---return the template diagram
---@return Diagram
function Template:get_template()
    return self.template_diagram
end

---Get a Port given a port priority
---@param bundle_port BundlePort to look up
---@return Port|nil
function Template:get_port(bundle_port)
    local name = bundle_port.item_name

    -- search for item filters first, they have priority
    if name then
        for _, port in ipairs(self.ports) do
            if port.items[name] then
                return port
            end
        end
    end

    -- print(string.format("Looking for port_type %d num %d priority %d", bundle_port.port_type, bundle_port.port_idx,
    -- bundle_port.priority))

    for _, port in ipairs(self.ports) do
        -- print(string.format("Have:       port_type %d num %d priority %d", port.port_type, port.num, port.priority))
        -- Note: fuel ports are assumed to be unique
        if bundle_port.port_type == PortType.FUEL and port.port_type == PortType.FUEL then
            return port
        elseif port.port_type == bundle_port.port_type and
            port.num == bundle_port.port_idx and
            port.priority == bundle_port.priority then
            return port
        end
    end

    return nil
end

local clocking_blueprint =
-- "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"

---Create a default template
---@param template_data table
---@param recipe RecipeInfo
---@param full_config FullConfig
---@return Template
function Template.default_template(template_data, recipe, full_config)
    -- we need number of input / output : items / fluids
    -- need machine_height
    local data = CoordTable.new()
    local machines = {}
    local ports = {}
    local item_idx = 0
    local fluid_idx = 1
    local coord = 0
    local tags = {}
    ---@type Primitive
    local clocking = Blueprint:from_string(clocking_blueprint):to_primitive(full_config.game_data.size_data)

    local function create_combinator(item, count)
        return ActionPair.new(
            Entity.new(
                "constant-combinator", EntityDirection.UP, {},
                {
                    control_behavior = {
                        filters = {
                            { signal = { type = item.item_type, name = item.name }, count = count or 1, index = 1 } }
                    }
                }
            ))
    end
    for idx, item in ipairs(recipe.recipe.outputs) do
        if item.item_type == ItemType.FLUID then
            table.insert(ports, Port.new(fluid_idx, coord, PortType.FLUID_OUTPUT, { item.name }, LanePriority.NORMAL))
            CoordTable.set(data, 0, coord, create_combinator(item))
            fluid_idx = fluid_idx + 1
            coord = coord + 2
            -- MetadataTags["envelope-up"].set_tag(tags, 1) -- just do this by default
        end
    end
    MetadataTags["envelope-up"].set_tag(tags, 1)
    for idx, item in ipairs(recipe.recipe.outputs) do
        if item.item_type == ItemType.ITEM then
            table.insert(ports, Port.new(item_idx, coord, PortType.ITEM_OUTPUT, { item.name }, LanePriority.NORMAL))
            CoordTable.set(data, 0, coord, create_combinator(item))
            item_idx = item_idx + 1
            coord = coord + 1
            if item_idx % 4 == 1 and idx < #recipe.recipe.inputs then
                coord = coord + 2
            end
        end
    end

    -- add space for the machines and add a wire halfway down
    coord = coord + math.floor(template_data.machine_height / 2)
    table.insert(ports, Port.new(DEFAULT_PORT_INDEX, coord, PortType.WIRE, {}, LanePriority.NORMAL))
    local clocking_diagram = Translate(0, coord, clocking)

    -- constant combinator with number of machines
    CoordTable.set(data, 1, 0,
        create_combinator({ item_type = ItemType.ITEM, name = recipe.machine_name }, math.ceil(recipe.machine_count)))

    coord = coord + (template_data.machine_height - math.floor(template_data.machine_height / 2))
    item_idx = 0
    fluid_idx = 1
    for idx, item in ipairs(recipe.recipe.inputs) do
        if item.item_type == ItemType.ITEM then
            table.insert(ports, Port.new(item_idx, coord, PortType.ITEM_INPUT, { item.name }, LanePriority.NORMAL))
            CoordTable.set(data, 0, coord, create_combinator(item))
            item_idx = item_idx + 1
            coord = coord + 1
            if item_idx % 4 == 1 and idx < #recipe.recipe.inputs then
                coord = coord + 2
            end
        end
    end
    for idx, item in ipairs(recipe.recipe.inputs) do
        if item.item_type == ItemType.FLUID then
            table.insert(ports, Port.new(fluid_idx, coord, PortType.FLUID_INPUT, { item.name }, LanePriority.NORMAL))
            CoordTable.set(data, 0, coord, create_combinator(item))
            fluid_idx = fluid_idx + 1
            coord = coord + 2
            MetadataTags["envelope-down"].set_tag(tags, 1)
        end
    end

    local diagram = Beside(Primitive.new(data), clocking_diagram, Direction.RIGHT)
    return Template.new("Default_Template", diagram, machines, ports, tags)
end

---Create a Template from a Blueprint
---@param template_data TemplateData
---@param full_config FullConfig
---@return Template
function Template.from_blueprint(template_data, full_config)
    ---@type Port[]
    local ports = {}
    ---@type coord[]
    local envelope_points = {}  -- array of coords
    ---@type {coord: int, number:int}[]
    local machine_split_xs = {} -- array of tables with coord and number keys, int values
    ---@type int?
    local machine_end_x         -- optional int
    local machine_count = 1
    local blueprint, metadata_tags, row_tags, col_tags

    blueprint = Blueprint:from_string(template_data.blueprint, false, true)
    metadata_tags = template_data.metadata_tags --[[@as table<string,any>]]
    row_tags = template_data.row_tags --[[@as table<int,table<string,any>>]]
    col_tags = template_data.col_tags --[[@as table<int,table<string,any>>]]


    local primitive = blueprint:to_primitive(full_config.game_data.size_data)
    local min_x, max_x, min_y, max_y
    CoordTable.iterate(primitive.primitive, function(x, y, entity)
        if min_x == nil then min_x = x else min_x = math.min(min_x, x) end
        if max_x == nil then max_x = x else max_x = math.max(max_x, x) end
        if min_y == nil then min_y = y else min_y = math.min(min_y, y) end
        if max_y == nil then max_y = y else max_y = math.max(max_y, y) end
    end)

    -- work out metadata from metadata_tags
    -- nothing to do here, we just pass metadata tags on at the end

    -- work out machine split from col_tags
    for idx, col_data in pairs(col_tags) do
        -- print(string.format("%d, %s", idx, Dump(col_data)))
        local machine_num = ColTags["machine"].get_tag(col_data)
        if machine_num then
            table.insert(machine_split_xs, { coord = idx, number = tonumber(machine_num) or 1 }) -- machine_num could be true, so just treat as 1
        end
        if ColTags["machine-end"].get_tag(col_data) then
            machine_end_x = tonumber(idx)
        end
    end

    -- work out port data from row_tags

    for idx, row_data in pairs(row_tags) do
        -- find priority
        local priority = LanePriority.NORMAL
        local row_priority = RowTags.priority.get_tag(row_data)
        if row_priority == "high" then
            priority = LanePriority.HIGH
        elseif row_priority == "low" then
            priority = LanePriority.LOW
        elseif row_priority == "normal-up" then
            priority = LanePriority.NORMAL_UP
        elseif row_priority == "normal-down" then
            priority = LanePriority.NORMAL_DOWN
        end

        -- now work out port info
        local port_type
        local row_type = RowTags.type.get_tag(row_data)
        local row_input = RowTags.input.get_tag(row_data)
        local row_output = RowTags.output.get_tag(row_data)
        if row_type == "item" and row_input then
            port_type = PortType.ITEM_INPUT
        elseif row_type == "item" and row_output then
            port_type = PortType.ITEM_OUTPUT
        elseif row_type == "fluid" and row_input then
            port_type = PortType.FLUID_INPUT
        elseif row_type == "fluid" and row_output then
            port_type = PortType.FLUID_OUTPUT
        elseif row_type == "fuel" then
            port_type = PortType.FUEL
        elseif row_type == "wire" then
            port_type = PortType.WIRE
        end
        if port_type ~= nil then
            local port_number = tonumber(RowTags["port-number"].get_tag(row_data)) or DEFAULT_PORT_INDEX

            -- now get items
            local items = Split_string(row_data.items)
            table.insert(ports, Port.new(port_number, idx, port_type, items, priority, RowTags["name"].get_tag(row_data)))
        end
    end

    if machine_end_x == nil then
        machine_end_x = max_x + 1
    end

    -- split the diagrams via machine_split_x.
    -- If there isn't one then there are no machines,
    -- e.g. could be a buffer
    local machine_split_x
    if #machine_split_xs == 0 then
        machine_split_x = math.min(max_x, machine_end_x)
    else
        machine_split_x = machine_split_xs[1].coord
        for _, split in ipairs(machine_split_xs) do
            if split.coord < machine_split_x then
                machine_split_x = split.coord
            end
        end
    end

    -- sort them so the smallest are first
    table.sort(machine_split_xs, function(a, b)
        return a.coord < b.coord
    end)

    -- create list of data for machines
    ---@type {coord: int, number:int, prev_coord: int}[]
    local machine_data = {} -- array of tuples, coord, number
    local total_num_machines = 0
    local prev_coord = machine_split_x
    for _, split_info in ipairs(machine_split_xs) do
        if split_info.coord == machine_split_x then
            total_num_machines = total_num_machines + split_info.number
        else
            table.insert(machine_data, {
                coord = split_info.coord,
                number = total_num_machines,
                prev_coord = prev_coord
            })
            prev_coord = split_info.coord
            total_num_machines = total_num_machines + split_info.number
        end
    end

    if #machine_split_xs > 0 then
        -- don't add if there are no machines
        table.insert(machine_data, {
            coord = machine_end_x,
            number = total_num_machines,
            prev_coord = prev_coord
        })
    end

    -- sort the collection so biggest are first (?)
    table.sort(machine_data, function(a, b)
        return a.coord > b.coord
    end)

    ---@type CoordTable<ActionPair>
    local template = CoordTable.new()
    ---@type CoordTable<ActionPair>[]
    local machines = {}
    for i = 1, #machine_split_xs do
        table.insert(machines, CoordTable.new())
    end

    CoordTable.iterate(primitive.primitive, function(x, y, entity)
        if x >= machine_split_x then
            for idx, split_info in ipairs(machine_data) do
                if x < split_info.coord then
                    local new_data = entity.data:clone()
                    if x < split_info.prev_coord then
                        -- remove belt-end tag
                        new_data.tags = Deepcopy(new_data.tags)
                        EntityTags["belt-end"].set_tag(new_data, nil)
                    end
                    CoordTable.set(machines[idx], x - machine_split_x, y, ActionPair.new(
                        new_data, entity.action
                    ))
                end
            end
        else
            local existing = CoordTable.get(template, x, y)
            if existing then
                -- do nothing
            elseif (not full_config.clocked) and EntityTags.clocked.get_tag(entity.data) and entity.data.name == full_config.pump then
                local direction = entity.data.direction
                local new_entity = entity.data:clone()
                EntityTags.clocked.set_tag(new_entity, nil)
                local tags = Deepcopy(new_entity.tags)
                new_entity.name = full_config.pipe_item_name
                CoordTable.set(template, x, y, ActionPair.new(new_entity))
                if direction == EntityDirection.UP or direction == EntityDirection.DOWN then
                    CoordTable.set(template, x, y + 1,
                        ActionPair.new(Entity.new(full_config.pipe_item_name, EntityDirection.DOWN, tags, {})))
                else
                    CoordTable.set(template, x + 1, y,
                        ActionPair.new(Entity.new(full_config.pipe_item_name, EntityDirection.RIGHT, tags, {})))
                end
            else
                CoordTable.set(template, x, y, entity)
            end
        end
    end)

    -- now create the diagrams
    local template_diagram = Primitive.new(template)
    ---@type Diagram[]
    local machines_diagram = {} -- array of diagrams
    for idx, data in ipairs(machine_data) do
        table.insert(machines_diagram, Machine.new(
            Primitive.new(machines[idx]),
            data.number
        ))
    end

    -- now correct envelope for ports
    -- each port adds an extra tile above and below
    local min_port
    local max_port
    for _, port in ipairs(ports) do
        if min_port == nil then
            min_port = port.coord
        end
        if max_port == nil then
            max_port = port.coord
        end
        if port.coord < min_port then
            min_port = port.coord
        end
        if port.coord > max_port then
            max_port = port.coord
        end
    end
    local envelope = template_diagram:envelope()
    if envelope == nil then
        assert(false, "Template diagram envelope is nil")
    end

    -- we need to create a bounding box and convert to envelope
    local template_envelope = Envelope.new(0, 0, 0, 0)

    -- calculate extra envelope points
    for _, coord in pairs(envelope_points) do
        template_envelope = template_envelope:compose(Envelope.from_point(coord.x, coord.y))
    end

    local final_template_diagram = template_diagram:set_envelope(template_envelope:compose(envelope))

    return Template.new(
        blueprint.label,
        final_template_diagram,
        machines_diagram,
        ports,
        metadata_tags
    )
end

---ClockedTemplate: a template that is limited by combinators and a clock
---@class ClockedTemplate : BaseClass
---@field template Template
---@field flow_rates table<string, float>
---@field timescale int
ClockedTemplate = InheritsFrom(nil)

-- template: Template
-- flow_rates: table of string to floats
-- timescale: int default 0 (not set), in seconds
---Create a new ClockedTemplate
---@param template Template
---@param flow_rates table<string, float>
---@param timescale int
---@return ClockedTemplate
function ClockedTemplate.new(template, flow_rates, timescale)
    local self = ClockedTemplate:create()
    self.template = template
    self.flow_rates = flow_rates
    self.timescale = timescale
    return self
end

---Init TemplateFactory
---@param full_config FullConfig
function TemplateFactory_init(full_config)
    for _, template in pairs(full_config.template_data) do
        template.template = Template.from_blueprint(template.template_data, full_config)
    end
end
