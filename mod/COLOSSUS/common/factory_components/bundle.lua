-- bundles - these are collections of lanes.  They also handle bypasses

require("common.factorio_objects.blueprint")
require("common.schematic.diagram")
require("common.factorio_objects.entity")
require("common.factory_components.lane")
require("common.transformations")
require("common.factory_components.tags")

require("common.utils.utils")

---PortType: type of a port
---@enum PortType
PortType = {
    ITEM_INPUT = 1,
    ITEM_OUTPUT = 2,
    FLUID_INPUT = 3,
    FLUID_OUTPUT = 4,
    WIRE = 5,
    FUEL = 6,
}

---A port
---@class Port : BaseClass
---@field num int port number
---@field coord int port y-coordinate
---@field port_type PortType type of port
---@field items string[]
---@field priority LanePriority
---@field name? string A named port
Port = InheritsFrom(nil)

DEFAULT_PORT_INDEX = 1

---Create a new Port
---@param num int
---@param coord int port y-coordinate
---@param port_Type PortType
---@param items string[]
---@param priority LanePriority
---@param name? string
---@return Port
function Port.new(num, coord, port_Type, items, priority, name)
    local self = Port:create()
    self.num = num
    self.coord = coord
    self.port_type = port_Type
    self.items = items
    self.priority = priority
    self.name = name
    return self
end

---BundlePort: match a bundle and internal lane with a port
---@class BundlePort : BaseClass
---@field bundle_idx int index of bundle
---@field strand_idx int  index of strand inside bundle
---@field item_name string item name
---@field port_type PortType port type
---@field port_idx? int for port index
---@field priority LanePriority lane priority
---@field flow_rate? float flow rate, default 0.0
BundlePort = InheritsFrom(nil)

---Create a new BundlePort
---@param bundle_idx int index of bundle
---@param strand_idx int index of strand inside bundle
---@param item_name string
---@param port_type PortType
---@param port_idx? int
---@param priority LanePriority
---@param flow_rate? float default 0.0
---@return BundlePort
function BundlePort.new(bundle_idx, strand_idx, item_name, port_type, port_idx, priority, flow_rate)
    local self = BundlePort:create()
    self.bundle_idx = bundle_idx
    self.strand_idx = strand_idx
    self.item_name = item_name
    self.port_type = port_type
    self.port_idx = port_idx
    self.priority = priority
    self.flow_rate = flow_rate or 0.0
    return self
end

---BundleBypass: a bypass over a bundle
---@class BundleBypass : BaseClass
---@field bundle_idx int index of bundle
---@field port BundlePort thatthis aligns with
BundleBypass = InheritsFrom(nil)

---Create a new BundleBypass
---@param bundle_idx int index of bundle
---@param port BundlePort thatthis aligns with
---@return BundleBypass
function BundleBypass.new(bundle_idx, port)
    local self = BundleBypass:create()
    self.bundle_idx = bundle_idx
    self.port = port
    return self
end

---convert a BundlePort to a BundleBypass
---@param bypass_idx int index of bypass
---@return BundleBypass
function BundlePort:to_bypass(bypass_idx)
    return BundleBypass.new(bypass_idx, self)
end

---LanePort: match a lane with a port
---@class LanePort : BaseClass
---@field lane_idx int
---@field item_name string
---@field port_type PortType
---@field port_idx? int
---@field priority LanePriority
---@field flow_rate? float default 0.0
LanePort = InheritsFrom(nil)


---comment Create a new LanePort
---@param lane_idx int
---@param item_name string
---@param port_type PortType
---@param port_idx? int
---@param priority LanePriority
---@param flow_rate? float default 0.0
---@return LanePort
function LanePort.new(lane_idx, item_name, port_type, port_idx, priority, flow_rate)
    local self = LanePort:create()
    self.lane_idx = lane_idx
    self.item_name = item_name
    self.port_type = port_type
    self.port_idx = port_idx
    self.priority = priority
    self.flow_rate = flow_rate or 0.0
    return self
end

---convert to a LanePort to a BundlePort
---@param bundle_idx int index of bundle
---@param strand_idx int index of strand inside bundle
---@return BundlePort
function LanePort:to_bundle_port(bundle_idx, strand_idx)
    return BundlePort.new(
        bundle_idx,
        strand_idx,
        self.item_name,
        self.port_type,
        self.port_idx,
        self.priority,
        self.flow_rate
    )
end

---Return a new LanePort with an updated index
---@param new_idx int new index
---@return LanePort
function LanePort:update_idx(new_idx)
    return LanePort.new(
        new_idx,
        self.item_name,
        self.port_type,
        self.port_idx,
        self.priority,
        self.flow_rate
    )
end

---Bundle: a bundle of lanes (strands)
---@class Bundle : BaseClass
---@field lanes Lane[]
---@field width int widht of each bundle
Bundle = InheritsFrom(nil)

---Create a new Bundle
---@param lanes Lane[]
---@param width int widht of each bundle
---@return Bundle
function Bundle.new(lanes, width)
    local self = Bundle:create()
    self.lanes = lanes
    self.width = width
    return self
end

-- abstract methods

---Draw a bundle, abstract method
---@param recipe_idx int
---@param height int
---@param y_base int where to start y from
---@param taps Tap[]
---@param bypasses Bypass[]
---@param full_config FullConfig
---@param flowrates table
---@param recipe_type RecipeType
---@return Diagram
function Bundle:draw_bundle(recipe_idx, height, y_base, taps, bypasses, full_config, flowrates, recipe_type)
    return Empty.new()
end

---Abstract method, draw the signals for this bundle
---@return { type: string, name: string []}
function Bundle:get_bundle_signals()
    return {}
end

---Initialize bypass primitivies
---@param full_config FullConfig
local function init_bypass(full_config)
    if full_config.bypass_data == nil then
        full_config.bypass_data = {}

        local size_data = full_config.game_data.size_data
        -- full_config.bypass_data.RIGHT_BYPASS = full_config.blueprint_data.bypass_blueprints["even-belt-bypass"]
        --     :to_primitive(size_data)
        full_config.bypass_data.RIGHT_BYPASS = Primitive.new(CoordTable.from_array({ {
            x = 2,
            y = 0,
            value = ActionPair.new(Entity.new("underground-belt", EntityDirection.RIGHT, {}, { type = "output" }))
        } }))
        full_config.bypass_data.LEFT_BYPASS = full_config.blueprint_data.bypass_blueprints["odd-belt-bypass"]
            :to_primitive(size_data)
        full_config.bypass_data.RIGHT_PIPE_BYPASS = full_config.blueprint_data.bypass_blueprints["even-pipe-bypass"]
            :to_primitive(size_data)
        full_config.bypass_data.LEFT_PIPE_BYPASS = full_config.blueprint_data.bypass_blueprints["odd-pipe-bypass"]
            :to_primitive(size_data)
        full_config.bypass_data.EMPTY_INPUT_BYPASS = full_config.blueprint_data.bypass_blueprints["empty-input-bypass"]
            :to_primitive(
                size_data)
        full_config.bypass_data.EMPTY_OUTPUT_BYPASS = full_config.blueprint_data.bypass_blueprints
            ["empty-output-bypass"]:to_primitive(
                size_data)
        full_config.bypass_data.RIGHT_BYPASS_CLOCKED = full_config.blueprint_data.bypass_blueprints
            ["even-belt-bypass-clocked"]
            :to_primitive(size_data)
        full_config.bypass_data.RIGHT_BYPASS_INPUT = Primitive.new(
            Transformations.reverse_belts_in_primitive(
                full_config.bypass_data.RIGHT_BYPASS.primitive, full_config
            )
        )
        full_config.bypass_data.LEFT_BYPASS_INPUT = Primitive.new(
            Transformations.reverse_belts_in_primitive(
                full_config.bypass_data.LEFT_BYPASS.primitive, full_config
            )
        )
    end
end

---TwoLaneHeterogeneousBundle: a bundle with two strands,
---each with possibly different items
---@class TwoLaneHeterogeneousBundle : Bundle
TwoLaneHeterogeneousBundle = InheritsFrom(Bundle)

local function create_pipe_taps(full_config)
    local envelope = Envelope.new(0, 0, 0, 0)
    local data = CoordTable.new()
    CoordTable.set(data, 0, 0, ActionPair.new(Entity.new(full_config.pipe_item_name, EntityDirection.UP, {}, {})))
    CoordTable.set(data, 0, -1,
        ActionPair.new(Entity.new(full_config.pipe_underground_name, EntityDirection.DOWN, {}, {})))
    CoordTable.set(data, 0, 1, ActionPair.new(Entity.new(full_config.pipe_underground_name, EntityDirection.UP, {}, {})))
    CoordTable.set(data, 1, 0,
        ActionPair.new(Entity.new(full_config.pipe_underground_name, EntityDirection.LEFT, {}, {})))
    CoordTable.set(data, 2, 0,
        ActionPair.new(Entity.new(full_config.pipe_underground_name, EntityDirection.RIGHT, {}, {})))
    local full_tap = Primitive.new(data):set_envelope(envelope)
    data = CoordTable.new()
    CoordTable.set(data, 0, 0, ActionPair.new(Entity.new(full_config.pipe_item_name, EntityDirection.UP, {}, {})))
    -- CoordTable.set(data, 0, -1,
    -- ActionPair.new(Entity.new(full_config.pipe_underground_name, EntityDirection.DOWN, {}, {})))
    CoordTable.set(data, 0, 1, ActionPair.new(Entity.new(full_config.pipe_underground_name, EntityDirection.UP, {}, {})))
    CoordTable.set(data, 1, 0,
        ActionPair.new(Entity.new(full_config.pipe_underground_name, EntityDirection.LEFT, {}, {})))
    CoordTable.set(data, 2, 0,
        ActionPair.new(Entity.new(full_config.pipe_underground_name, EntityDirection.RIGHT, {}, {})))
    local end_tap = Primitive.new(data):set_envelope(envelope)
    data = CoordTable.new()
    CoordTable.set(data, 0, 0, ActionPair.new(Entity.new(full_config.pipe_item_name, EntityDirection.UP, {}, {})))
    CoordTable.set(data, 0, -1,
        ActionPair.new(Entity.new(full_config.pipe_underground_name, EntityDirection.DOWN, {}, {})))
    -- CoordTable.set(data, 0, 1, ActionPair.new(Entity.new(full_config.pipe_underground_name, EntityDirection.UP, {}, {})))
    CoordTable.set(data, 1, 0,
        ActionPair.new(Entity.new(full_config.pipe_underground_name, EntityDirection.LEFT, {}, {})))
    CoordTable.set(data, 2, 0,
        ActionPair.new(Entity.new(full_config.pipe_underground_name, EntityDirection.RIGHT, {}, {})))
    local start_tap = Primitive.new(data):set_envelope(envelope)
    return full_tap, start_tap, end_tap
end

---Init two lane bundle
---@param full_config FullConfig
local function init_twolane(full_config)
    init_bypass(full_config)
    if full_config.bundle_data == nil then
        full_config.bundle_data = {}
    end
    if full_config.bundle_data.twolane == nil then
        full_config.bundle_data.twolane = {}
        full_config.bundle_data.multilane = {}

        local BLUEPRINTS = full_config.blueprint_data.bundle_blueprints["Two Lane Bundle"]
        local multilane_blueprints = full_config.blueprint_data.bundle_blueprints["Four Lane Bundle"]

        local size_data = full_config.game_data.size_data

        -- special primitives
        full_config.bundle_data.twolane.RIGHT_TAP = BLUEPRINTS["even-belt-priority-tap"]:to_primitive(size_data)
        full_config.bundle_data.twolane.LEFT_TAP = BLUEPRINTS["odd-belt-priority-tap"]:to_primitive(size_data)
        full_config.bundle_data.twolane.RIGHT_OUTPUT_TAP = Primitive.new(
            Transformations.flip_primitive_vertical(
                Transformations.reverse_belts_in_primitive(
                    full_config.bundle_data.twolane.RIGHT_TAP.primitive, full_config
                )
            )
        )
        full_config.bundle_data.twolane.LEFT_OUTPUT_TAP = Primitive.new(
            Transformations.flip_primitive_vertical(
                Transformations.reverse_belts_in_primitive(
                    full_config.bundle_data.twolane.LEFT_TAP.primitive, full_config
                )
            )
        )

        -- pipes
        full_config.bundle_data.twolane.RIGHT_PIPE_TAP = BLUEPRINTS["even-pipe-tap"]:to_primitive(size_data)
        full_config.bundle_data.twolane.LEFT_PIPE_TAP = BLUEPRINTS["odd-pipe-tap"]:to_primitive(size_data)

        local full_tap, start_tap, end_tap = create_pipe_taps(full_config)
        full_config.bundle_data.multilane.RIGHT_PIPE_TAP = full_tap
        full_config.bundle_data.multilane.RIGHT_PIPE_BEGIN_TAP = start_tap
        full_config.bundle_data.multilane.RIGHT_PIPE_END_TAP = end_tap


        -- begin and end taps
        full_config.bundle_data.twolane.BEGIN_RIGHT_TAP = BLUEPRINTS["begin-even-tap"]:to_primitive(size_data)
        full_config.bundle_data.twolane.BEGIN_LEFT_TAP = BLUEPRINTS["begin-odd-tap"]:to_primitive(size_data)
        full_config.bundle_data.twolane.END_RIGHT_TAP = BLUEPRINTS["end-even-tap"]:to_primitive(size_data)
        full_config.bundle_data.twolane.END_LEFT_TAP = BLUEPRINTS["end-odd-tap"]:to_primitive(size_data)
    end
end

---Create a one lane bundle
---@param lane Lane
---@param full_config FullConfig
---@return TwoLaneHeterogeneousBundle
function TwoLaneHeterogeneousBundle.create_one_lane_bundle(lane, full_config)
    init_twolane(full_config)
    local self = TwoLaneHeterogeneousBundle:create()
    self.lanes = { lane }
    self.width = 1
    return self
end

---Create a two lane bundle
---@param first_lane Lane
---@param second_lane Lane
---@param full_config FullConfig
---@return TwoLaneHeterogeneousBundle
function TwoLaneHeterogeneousBundle.create_two_lane_bundle(first_lane, second_lane, full_config)
    init_twolane(full_config)
    local self = TwoLaneHeterogeneousBundle:create()
    self.lanes = { first_lane, second_lane }
    self.width = 2
    return self
end

---Tap: a tap
---@class Tap : BaseClass
---@field strand_idx int
---@field coord int
---@field port_type PortType
Tap = InheritsFrom(nil)

---Create a new Tap
---@param strand_idx int
---@param coord int
---@param port_type PortType
---@return Tap
function Tap.new(strand_idx, coord, port_type)
    local self = Tap:create()
    self.strand_idx = strand_idx
    self.coord = coord
    self.port_type = port_type
    return self
end

--Bypass: a bypass
---@class Bypass : BaseClass
---@field coord int
---@field port_type PortType
Bypass = InheritsFrom(nil)

---Create a new Bypass
---@param coord int
---@param port_type PortType
---@return Bypass
function Bypass.new(coord, port_type)
    local self = Bypass:create()
    self.coord = coord
    self.port_type = port_type
    return self
end

---Draw this bundle
---@param recipe_idx int index of recipe
---@param height int
---@param y_base int where to start y from
---@param taps {index: int, coord: int, type: PortType, port: Port}[]
---@param bypasses {coord: int, type: PortType}[]
---@param full_config FullConfig
---@return Diagram
function TwoLaneHeterogeneousBundle:draw_bundle(recipe_idx, height, y_base, taps, bypasses, full_config)
    local first_taps = {}
    for _, tap_info in ipairs(taps) do
        if tap_info.index == 1 then
            table.insert(first_taps, tap_info.coord)
        end
    end
    local diagram, status = self.lanes[1]:draw_lane(recipe_idx, y_base, y_base + height, first_taps, -1)

    -- draw taps for right lane
    local tap = full_config.bundle_data.twolane.RIGHT_TAP
    local output_tap = full_config.bundle_data.twolane.RIGHT_OUTPUT_TAP
    if status == LaneStatus.BEGIN or status == LaneStatus.OUTPUT_BEGIN then
        tap = full_config.bundle_data.twolane.BEGIN_RIGHT_TAP
        output_tap = tap
    end
    if status == LaneStatus.END or status == LaneStatus.INPUT_END then
        tap = full_config.bundle_data.twolane.END_RIGHT_TAP
        output_tap = tap
    end
    if self.lanes[1].direction == LaneDirection.DOWN then
        tap = Primitive.new(Transformations.flip_primitive_vertical(tap.primitive))
        tap = Primitive.new(Transformations.flip_primitive_vertical(output_tap.primitive))
    end

    for _, tap_info in ipairs(taps) do
        if tap_info.index == 1 then
            local switch = output_tap
            if tap_info.type == PortType.FLUID_INPUT or tap_info.type == PortType.FLUID_OUTPUT then
                switch = full_config.bundle_data.twolane.RIGHT_PIPE_TAP
            elseif tap_info.type == PortType.ITEM_INPUT then
                switch = tap
            end
            diagram = Translate(0, tap_info.coord, switch):compose(diagram)
        end
    end

    -- draw bypasses for right lane
    for _, bypass in ipairs(bypasses) do
        local bypass_diagram
        if bypass.type == PortType.FLUID_INPUT or bypass.type == PortType.FLUID_OUTPUT then
            bypass_diagram = full_config.bypass_data.RIGHT_PIPE_BYPASS
        elseif bypass.type == PortType.ITEM_INPUT then
            bypass_diagram = full_config.bypass_data.RIGHT_BYPASS
        else
            bypass_diagram = Primitive.new(
                Transformations.reverse_belts_in_primitive(
                    full_config.bypass_data.RIGHT_BYPASS.primitive, full_config
                )
            )
        end
        diagram = Translate(0, bypass.coord, bypass_diagram):compose(diagram)
    end

    -- if no other lanes, draw left bypasses as well
    if self.width == 1 then
        for _, bypass in ipairs(bypasses) do
            local bypass_diagram
            if bypass.type == PortType.FLUID_INPUT or bypass.type == PortType.FLUID_OUTPUT then
                bypass_diagram = full_config.bypass_data.LEFT_PIPE_BYPASS
            elseif bypass.type == PortType.ITEM_INPUT then
                bypass_diagram = full_config.bypass_data.LEFT_BYPASS
            else
                bypass_diagram = Primitive.new(
                    Transformations.reverse_belts_in_primitive(
                        full_config.bypass_data.LEFT_BYPASS.primitive, full_config
                    )
                )
            end
            diagram = Translate(0, bypass.coord, bypass_diagram):compose(diagram)
        end

        -- ensure envelope is set correctly and return single lane
        local envelope = diagram:envelope()
        return self.lanes[1]:finalize_lane(diagram):set_envelope(Envelope.new(1, 1, height - 2, 1):compose(envelope))
    end

    -- there are two lanes, so now draw the left one
    local left_taps = {}
    for _, tap_info in ipairs(taps) do
        if tap_info.index == 2 then
            table.insert(left_taps, tap_info.coord)
        end
    end
    local diagram2, status2 = self.lanes[2]:draw_lane(
        recipe_idx, y_base, y_base + height, left_taps, -1
    )

    -- draw taps for left lane
    tap = full_config.bundle_data.twolane.LEFT_TAP
    output_tap = full_config.bundle_data.twolane.LEFT_OUTPUT_TAP
    if status2 == LaneStatus.BEGIN or status2 == LaneStatus.OUTPUT_BEGIN then
        tap = full_config.bundle_data.twolane.BEGIN_LEFT_TAP
        output_tap = tap
    end
    if status2 == LaneStatus.END or status2 == LaneStatus.INPUT_END then
        tap = full_config.bundle_data.twolane.END_LEFT_TAP
        output_tap = tap
    end
    if self.lanes[2].direction == LaneDirection.DOWN then
        tap = Primitive.new(Transformations.flip_primitive_vertical(tap.primitive))
        tap = Primitive.new(Transformations.flip_primitive_vertical(output_tap.primitive))
    end

    for _, tap_info in ipairs(taps) do
        if tap_info.index == 2 then
            local switch = output_tap
            if tap_info.type == PortType.FLUID_INPUT or tap_info.type == PortType.FLUID_OUTPUT then
                switch = full_config.bundle_data.twolane.LEFT_PIPE_TAP
            elseif tap_info.type == PortType.ITEM_INPUT then
                switch = tap
            end
            diagram2 = Translate(0, tap_info.coord, switch):compose(diagram2)
        end
    end

    -- draw bypasses for left lane
    for _, bypass in ipairs(bypasses) do
        local bypass_diagram
        if bypass.type == PortType.FLUID_INPUT or bypass.type == PortType.FLUID_OUTPUT then
            bypass_diagram = full_config.bypass_data.LEFT_PIPE_BYPASS
        elseif bypass.type == PortType.ITEM_INPUT then
            bypass_diagram = full_config.bypass_data.LEFT_BYPASS
        else
            bypass_diagram = Primitive.new(
                Transformations.reverse_belts_in_primitive(
                    full_config.bypass_data.LEFT_BYPASS.primitive, full_config
                )
            )
        end
        diagram2 = Translate(0, bypass.coord, bypass_diagram):compose(diagram2)
    end

    -- now compose the two lanes
    diagram = self.lanes[1]:finalize_lane(diagram):compose(
        Translate(-2, 0, self.lanes[2]:finalize_lane(diagram2))
    )

    -- draw empty bypasses
    -- TODO replace this with optimizer
    if status == LaneStatus.EMPTY and status2 == LaneStatus.EMPTY then
        for _, bypass_info in ipairs(bypasses) do
            if not (bypass_info.type == PortType.FLUID_INPUT or
                    bypass_info.type == PortType.FLUID_OUTPUT) then
                local bypass_diagram
                if bypass_info.type == PortType.ITEM_INPUT then
                    bypass_diagram = full_config.bypass_data.EMPTY_INPUT_BYPASS
                else
                    bypass_diagram = full_config.bypass_data.EMPTY_OUTPUT_BYPASS
                end
                diagram = Translate(0, bypass_info.coord, bypass_diagram):compose(diagram)
            end
        end
    end

    local envelope = diagram:envelope()

    -- ensure Envelope is set correctly
    return diagram:set_envelope(Envelope.new(3, 1, height - 2, 1):compose(envelope))
end

-- ---draw lane info: draw a combinator with info about this lane
-- ---@return Diagram
-- function TwoLaneHeterogeneousBundle:draw_lane_info()
--     local diagram = self.lanes[1]:lane_to_combinator()
--     if #self.lanes > 1 then
--         diagram = Beside(
--             diagram,
--             self.lanes[2]:lane_to_combinator(),
--             Direction.LEFT,
--             1
--         )
--     end
--     return diagram
-- end

---Returns an array of signals for this bundle
---@return { type: string, name: string []}
function TwoLaneHeterogeneousBundle:get_bundle_signals()
    error("TwoLaneHeterogeneousBundle get_bundle_signals not implemented")
    local output = self.lanes[1]:lane_to_signal()
    return output
end

---MultiLaneBundle: Bundle with multiple lanes but all of one item
---@class MultiLaneBundle : Bundle
MultiLaneBundle = InheritsFrom(Bundle)


---Create a MultiLaneBundle
---@param lane Lane
---@param width int
---@param full_config FullConfig
---@return MultiLaneBundle
function MultiLaneBundle.new(lane, width, full_config)
    init_twolane(full_config)
    local self = MultiLaneBundle:create()
    self.lanes = { lane }
    self.width = width
    return self
end

MultiLaneBundle.delete = ActionPair.new(
    Entity.new(
        DELETE_TAG, EntityDirection.UP, { [DELETE_TAG] = true }, nil
    ),
    nil
)
MultiLaneBundle.RIGHT_WIDTH = 2

-- TODO simplify these


---Draw an up output tap
---Some belts are tagged for clocking purposes
---@param size int
---@param port Port
---@param flowrate table
---@param prioritized? boolean
---@param end_tap? boolean
---@return Diagram
function MultiLaneBundle:draw_up_output_tap_clocked(size, port, flowrate, prioritized, end_tap)
    local splitter_args = {}
    if prioritized then
        splitter_args = { output_priority = "right" }
    end
    local splitter = ActionPair.new(
        Entity.new(
            "splitter", EntityDirection.UP, nil, splitter_args
        ),
        nil
    )

    local data = CoordTable.new()
    local belt_flowrate = flowrate[port.num].flowrate
    -- ensure that something always comes through every time period
    if belt_flowrate < 1 then belt_flowrate = 1 end
    local args
    args = {
        control_behavior = {
            circuit_condition = {
                first_signal = {
                    type = "item",
                    name = flowrate[port.num].name
                },
                constant = math.max(math.floor(flowrate[port.num].flowrate), 1), -- use a floor, so slightly under.  max ensures something always flows
                comparator = "≤"
            },
            circuit_enable_disable = true,
            circuit_read_hand_contents = false,
            circuit_contents_read_mode = 0
        }
    }
    CoordTable.set(data, 1, 0, ActionPair.new(
        Entity.new("transport-belt", EntityDirection.RIGHT,
            { [EntityTags.blocker.name] = true }, args), nil
    ))
    args = {
        control_behavior = {
            circuit_enable_disable = false,
            circuit_read_hand_contents = true,
            circuit_contents_read_mode = 0
        }
    }
    CoordTable.set(data, 2, 0, ActionPair.new(
        Entity.new("transport-belt", EntityDirection.RIGHT,
            { [EntityTags.reader.name] = true }, args), nil
    ))
    local idx = 0
    if end_tap == true then
        -- don't draw the first splitter
        CoordTable.set(data, -idx, idx,
            ActionPair.new(Entity.new("transport-belt", EntityDirection.RIGHT), nil))
        idx = idx + 1
        size = size - 1
    end
    while size > 0 do
        CoordTable.set(data, -idx, idx + 1, splitter)
        CoordTable.set(data, -idx + 1, idx + 1, self.delete)
        size = size - 1
        idx = idx + 1
    end

    -- envelope is set small so this overlaps with other diagrams
    return Primitive.new(data):set_envelope(Envelope.new(0, 0, 0, 0))
end

---Draw an up output tap, unclocked
---@param size int
---@param end_tap? boolean
---@return Diagram
function MultiLaneBundle:draw_up_output_tap(size, end_tap)
    if end_tap == true then
        error("Unclocked end output taps not implemented yet")
    end
    local splitter = ActionPair.new(
        Entity.new(
            "splitter", EntityDirection.UP, nil, { output_priority = "right" }
        ),
        nil
    )

    local data = CoordTable.new()
    CoordTable.set(data, 1, 0, ActionPair.new(
        Entity.new("transport-belt", EntityDirection.RIGHT), nil
    ))
    CoordTable.set(data, 2, 0, ActionPair.new(
        Entity.new("transport-belt", EntityDirection.RIGHT), nil
    ))

    local idx = 0
    while size > 0 do
        CoordTable.set(data, -idx, idx + 1, splitter)
        CoordTable.set(data, -idx + 1, idx + 1, self.delete)
        size = size - 1
        idx = idx + 1
    end

    -- envelope is set small so this overlaps with other diagrams
    return Primitive.new(data):set_envelope(Envelope.new(0, 0, 0, 0))
end

---Draw an up input tap
---@param size int
---@param begin_tap? boolean
---@return Diagram
function MultiLaneBundle:draw_up_input_tap(size, begin_tap)
    local splitter = ActionPair.new(
        Entity.new(
            "splitter", EntityDirection.UP, nil, { output_priority = "left" }
        ),
        nil
    )

    local data = CoordTable.new()
    local direction = EntityDirection.UP
    if begin_tap == true then
        direction = EntityDirection.LEFT
    end
    CoordTable.set(data, 1, 0, ActionPair.new(
        Entity.new("transport-belt", direction, nil, nil), nil
    ))
    CoordTable.set(data, 2, 0, ActionPair.new(
        Entity.new("transport-belt", EntityDirection.LEFT, nil, nil), nil
    ))
    local idx = 0
    if begin_tap == true then
        -- don't draw the first splitter
        CoordTable.set(data, -idx, idx,
            ActionPair.new(Entity.new("transport-belt", EntityDirection.UP), nil))
        idx = idx + 1
        size = size - 1
    end
    while size > 0 do
        CoordTable.set(data, -idx, idx - 1, splitter)
        CoordTable.set(data, -idx + 1, idx - 1, self.delete)
        size = size - 1
        idx = idx + 1
    end

    -- envelope is set small so this overlaps with other diagrams
    return Primitive.new(data):set_envelope(Envelope.new(0, 0, 0, 0))
end

---Draw a down output tap
---@param size int
---@param end_tap? boolean
---@return Diagram
function MultiLaneBundle:draw_down_output_tap(size, end_tap)
    local splitter = ActionPair.new(
        Entity.new(
            "splitter", EntityDirection.DOWN, nil, { output_priority = "left" }
        ),
        nil
    )
    local direction = EntityDirection.RIGHT
    -- if begin_tap == true then
    --     direction = EntityDirection.LEFT
    -- end
    local data = CoordTable.new()
    CoordTable.set(data, 1, 0, ActionPair.new(
        Entity.new("transport-belt", direction, nil, nil), nil
    ))
    CoordTable.set(data, 2, 0, ActionPair.new(
        Entity.new("transport-belt", EntityDirection.RIGHT, nil, nil), nil
    ))
    local idx = 0
    if end_tap == true then
        -- don't draw the first splitter
        CoordTable.set(data, -idx, idx,
            ActionPair.new(Entity.new("transport-belt", EntityDirection.RIGHT), nil))
        idx = idx + 1
        size = size - 1
    end
    while size > 0 do
        CoordTable.set(data, -idx, -idx - 1, splitter)
        CoordTable.set(data, -idx + 1, -idx - 1, self.delete)
        size = size - 1
        idx = idx + 1
    end

    -- envelope is set small so this overlaps with other diagrams
    return Primitive.new(data):set_envelope(Envelope.new(0, 0, 0, 0))
end

---Draw a down input tap
---@param size int
---@param begin_tap? boolean
---@return Diagram
function MultiLaneBundle:draw_down_input_tap(size, begin_tap)
    local splitter = ActionPair.new(
        Entity.new(
            "splitter", EntityDirection.DOWN, nil, { output_priority = "right" }
        ),
        nil
    )

    local data = CoordTable.new()
    local direction = EntityDirection.DOWN
    if begin_tap == true then
        direction = EntityDirection.LEFT
    end
    CoordTable.set(data, 1, 0, ActionPair.new(
        Entity.new("transport-belt", direction, nil, nil), nil
    ))
    CoordTable.set(data, 2, 0, ActionPair.new(
        Entity.new("transport-belt", EntityDirection.LEFT, nil, nil), nil
    ))
    local idx = 0
    if begin_tap == true then
        -- don't draw the first splitter
        CoordTable.set(data, -idx, idx,
            ActionPair.new(Entity.new("transport-belt", EntityDirection.DOWN), nil))
        idx = idx + 1
        size = size - 1
    end
    while size > 0 do
        CoordTable.set(data, -idx, -idx + 1, splitter)
        CoordTable.set(data, -idx + 1, -idx + 1, self.delete)
        size = size - 1
        idx = idx + 1
    end

    -- envelope is set small so this overlaps with other diagrams
    return Primitive.new(data):set_envelope(Envelope.new(0, 0, 0, 0))
end

---Draw this bundle
---@param recipe_idx int index of recipe
---@param height int
---@param y_base int where to start y from
---@param taps {index: int, coord: int, type: PortType, port: Port}[]
---@param bypasses {coord: int, type: PortType}[]
---@param full_config FullConfig
---@param flowrates table
---@param recipe_type RecipeType
---@return Diagram
function MultiLaneBundle:draw_bundle(recipe_idx, height, y_base, taps, bypasses, full_config, flowrates, recipe_type)
    local tap_coords = {}
    for _, tap_info in ipairs(taps) do
        table.insert(tap_coords, tap_info.coord)
    end
    local lane = self.lanes[1]
    local lane_diagram, lane_status = lane:draw_lane(
        recipe_idx, y_base, y_base + height, tap_coords, 0
    )
    local end_tap = false
    local begin_tap = false
    if lane_status == LaneStatus.END or lane_status == LaneStatus.INPUT_END then
        end_tap = true
    elseif lane_status == LaneStatus.BEGIN or lane_status == LaneStatus.OUTPUT_BEGIN then
        begin_tap = true
    end
    -- the above are wrong for some down lanes
    if lane.priority == LanePriority.NORMAL_DOWN or lane.priority == LanePriority.LOW then
        if lane_status == LaneStatus.END then
            begin_tap = true
            end_tap = false
        elseif lane_status == LaneStatus.BEGIN then
            begin_tap = false
            end_tap = true
        end
    end
    local diagram = Empty.new()

    for i = 1, self.width do
        diagram = Beside(diagram, lane_diagram, Direction.LEFT)
    end

    -- draw taps
    local output_tap
    if lane.direction == LaneDirection.DOWN then
        output_tap = self:draw_down_input_tap(self.width, begin_tap)
    else
        output_tap = self:draw_up_input_tap(self.width, begin_tap)
    end
    for _, tap_info in ipairs(taps) do
        local switch = output_tap
        if tap_info.type == PortType.FLUID_INPUT or
            tap_info.type == PortType.FLUID_OUTPUT then
            switch = full_config.bundle_data.multilane.RIGHT_PIPE_TAP
            if lane_status == LaneStatus.END or lane_status == LaneStatus.INPUT_END or lane_status == LaneStatus.OUTPUT_BEGIN then
                switch = full_config.bundle_data.multilane.RIGHT_PIPE_END_TAP
            elseif lane_status == LaneStatus.BEGIN then
                switch = full_config.bundle_data.multilane.RIGHT_PIPE_BEGIN_TAP
            end
        elseif tap_info.type == PortType.ITEM_INPUT or tap_info.type == PortType.FUEL then
            if lane.direction == LaneDirection.DOWN then
                switch = self:draw_down_output_tap(self.width, end_tap)
            elseif recipe_type == RecipeType.BUFFER then
                switch = self:draw_up_output_tap(self.width, end_tap)
            else
                switch = self:draw_up_output_tap_clocked(self.width, tap_info.port, flowrates, full_config.clocked,
                    end_tap)
            end
        end
        diagram = Translate(0, tap_info.coord, switch):compose(diagram)
    end

    -- draw bypasses
    for _, bypass in ipairs(bypasses) do
        local bypass_right
        local bypass_left
        if bypass.type == PortType.WIRE then
            bypass_right = Empty.new()
            local coord = CoordTable.new()
            CoordTable.set(coord, 2, 0, ActionPair.new(Entity.new("medium-electric-pole", EntityDirection.DOWN), nil))
            bypass_left = Primitive.new(coord)
        elseif bypass.type == PortType.FLUID_INPUT or bypass.type == PortType.FLUID_OUTPUT then
            bypass_right = full_config.bypass_data.RIGHT_PIPE_BYPASS
            bypass_left = full_config.bypass_data.LEFT_PIPE_BYPASS
        elseif bypass.type == PortType.ITEM_INPUT or bypass.type == PortType.FUEL then
            bypass_right = full_config.bypass_data.RIGHT_BYPASS
            bypass_left = full_config.bypass_data.LEFT_BYPASS
        else
            bypass_right = full_config.bypass_data.RIGHT_BYPASS_INPUT
            bypass_left = full_config.bypass_data.LEFT_BYPASS_INPUT
        end
        diagram = diagram:compose(Translate(0, bypass.coord, bypass_right))
        -- TODO check this -3
        diagram = diagram:compose(Translate(-self.width + 1, bypass.coord, bypass_left))
    end

    -- for i = 1, self.width do
    --     diagram = Beside(diagram, lane_diagram, Direction.LEFT)
    -- end

    diagram = lane:finalize_lane(diagram)

    -- ensure envelope is set correctly
    local envelope = diagram:envelope()

    return diagram:set_envelope(Envelope.new(self.width, self.RIGHT_WIDTH, y_base + height - 1, -y_base):compose(
        envelope))
end

---Returns an array of signals for this bundle
---@return { type: string, name: string []}
function MultiLaneBundle:get_bundle_signals()
    local output = self.lanes[1]:lane_to_signal()
    return output
end

---Represents a collection of bundles all on top of each other
---@class OverlappingBundle : BaseClass
---@field bundles Bundle[]
OverlappingBundle = InheritsFrom(nil)

---Create a new OverlappingBundle
---@param bundles? Bundle[]
---@return OverlappingBundle
function OverlappingBundle.new(bundles)
    local self = OverlappingBundle:create()
    if bundles == nil then
        bundles = {}
    end
    self.bundles = bundles

    return self
end

---Draw an overlapping Bundle
---@param recipe_idx int index of recipe
---@param height int
---@param y_base int where to start y from
---@param taps {index: int, coord: int, type: PortType, port: Port}[][]
---@param bypasses {coord: int, type: PortType}[]
---@param full_config FullConfig
---@param flowrates table
---@param recipe_type RecipeType
---@return Diagram
function OverlappingBundle:draw_bundle(recipe_idx, height, y_base, taps, bypasses, full_config, flowrates, recipe_type)
    local diagram = Empty.new()
    for idx, bundle in ipairs(self.bundles) do
        diagram = diagram:compose(bundle:draw_bundle(recipe_idx, height, y_base, taps[idx], bypasses, full_config,
            flowrates,
            recipe_type))
    end

    return diagram
end

---Draw the lane info for this OverlappingBundle
---@return Primitive
function OverlappingBundle:draw_lane_info()
    local filters = {}
    local idx = 1
    for _, bundle in ipairs(self.bundles) do
        for _, signal in ipairs(bundle:get_bundle_signals()) do
            table.insert(filters, { signal = signal, count = 1, index = idx })
            idx = idx + 1
        end
    end
    local args = { control_behavior = { filters = filters } }
    local entity = Primitive.new(Primitives_to_actions(CoordTable.from_array
        { {
            x = 0,
            y = 0,
            value = Entity.new(
                "constant-combinator", EntityDirection.UP, nil, args)
        } }))
    return entity
end
