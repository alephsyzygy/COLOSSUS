-- lanes

require("common.schematic.diagram")
require("common.factorio_objects.blueprint")
require("common.factorio_objects.entity")
require("common.config.game_data")
require("common.schematic.grid")
require("common.factorio_objects.item")
require("common.schematic.primitive")

require("common.utils.utils")
require("common.schematic.coord_table")
require("common.utils.objects")

---@enum LaneDirection
LaneDirection = {
    UP = 1,
    DOWN = 2,
}

---priority of a lane
---@enum LanePriority
LanePriority = {
    NORMAL = 1,
    HIGH = 2, --[[excess elements, must be removed]]
    LOW = 3, --[[topup elements]]
    NORMAL_UP = 4,
    NORMAL_DOWN = 5,
}

local lane_chars = { "=", ">", "<", "^", "," }

---convert a lane priority to a character
---@param priority LanePriority
---@return string
function LanePriority.to_char(priority)
    return lane_chars[priority]
end

assert(LanePriority.to_char(LanePriority.NORMAL_UP) == "^")

---LaneStatus: Represents the lane behaviour at an index
---@enum LaneStatus
LaneStatus = {
    BEGIN = 1,
    END = 2,
    CONSTRUCT = 3,
    EMPTY = 4,
    INPUT = 5,      -- This lane is an input
    OUTPUT = 6,     -- This lane is an output
    BYPRODUCT = 7,  -- Byproduct lane, always construct
    BOTH = 8,       -- both begin and end, rare case but may appear with bus compression
    OUTPUT_BEGIN = 9,
    INPUT_END = 10, -- both an input and the end, i.e. is used immediately
}
---Should we construct this lane
---@param lane LaneStatus
---@return boolean
function LaneStatus.should_construct(lane)
    return lane ~= LaneStatus.EMPTY
end

LANESTATUS_STRING = {
    [LaneStatus.BEGIN] = "BEGIN",
    [LaneStatus.END] = "END",
    [LaneStatus.CONSTRUCT] = "CONSTRUCT",
    [LaneStatus.EMPTY] = "EMPTY",
    [LaneStatus.INPUT] = "INPUT",         -- This lane is an input
    [LaneStatus.OUTPUT] = "OUTPUT",       -- This lane is an output
    [LaneStatus.BYPRODUCT] = "BYPRODUCT", -- Byproduct lane, always construct
    [LaneStatus.BOTH] = "BOTH",           -- both begin and end, rare case but may appear with bus compression
    [LaneStatus.OUTPUT_BEGIN] = "OUTPUT_BEGIN",
    [LaneStatus.INPUT_END] = "INPUT_END", -- both an input and the end, i.e. is used immediately
}


---Represents a lane is a Bus.  Has an associated item and direction
---@class Lane : BaseClass
---@field item Item
---@field name string
---@field direction LaneDirection
---@field priority LanePriority
---@field idx int
---@field full_config FullConfig
---@field is_base_input boolean
---@field is_unused_lane boolean
---@field construct_range LaneStatus[]
---@field next_lane? Lane
---@field lane_type ItemType
---@field diagram Diagram
Lane = InheritsFrom(nil)

--- Delay Lane constants until blueprints have been initialized
---@param full_config FullConfig
local function init_lane(full_config)
    if full_config.lane_data == nil then
        full_config.lane_data = {}
        local size_data = full_config.game_data.size_data
        full_config.lane_data.BELT_LANE = full_config.blueprint_data.lane_blueprints["belt-lane"]:to_primitive(size_data)
        full_config.lane_data.PIPE_LANE = full_config.blueprint_data.lane_blueprints["pipe-lane"]:to_primitive(size_data)
        full_config.lane_data.PIPE_LANE_BEGIN = full_config.blueprint_data.lane_blueprints["pipe-lane-begin"]
            :to_primitive(
                size_data)
        full_config.lane_data.PIPE_LANE_END = full_config.blueprint_data.lane_blueprints["pipe-lane-end"]:to_primitive(
            size_data)
        full_config.lane_data.PIPE_FIX = full_config.blueprint_data.lane_blueprints["pipe-fix"]:to_primitive(size_data)
    end
end

---Create a new Lane
---@param item Item that is carried by this lane
---@param name string name of entity used to construct this lane
---@param direction LaneDirection
---@param priority LanePriority
---@param idx int
---@param full_config FullConfig
---@param is_base_input? boolean is this a base input lane
---@param is_unused_lane? boolean is this an unused lane
---@param construct_range? LaneStatus[]
---@param next_lane? Lane
---@return Lane
function Lane.new(item, name, direction, priority, idx, full_config, is_base_input,
                  is_unused_lane, construct_range, next_lane)
    init_lane(full_config)
    local self = Lane:create()
    self.item = item
    self.name = name
    self.direction = direction
    self.priority = priority
    self.idx = idx
    self.full_config = full_config
    self.is_base_input = is_base_input or false
    self.is_unused_lane = is_unused_lane or false
    self.construct_range = construct_range or {}
    self.next_lane = next_lane
    if next_lane ~= nil and next_lane.idx <= self.idx then
        error("Next lane must have a greater idx, idx: " .. self.idx .. " next_lane: " .. next_lane.idx)
    end

    self.lane_type = item.item_type
    if self.lane_type == ItemType.ITEM then
        self.diagram = full_config.lane_data.BELT_LANE
    else
        self.diagram = full_config.lane_data.PIPE_LANE
    end
    return self
end

function Lane:set_next_lane(next_lane)
    if next_lane.idx <= self.idx then
        error("Next lane must have a greater idx, idx: " .. self.idx .. " next_lane: " .. next_lane.idx)
    end
    self.next_lane = next_lane
end

---clone a lane with a new index, removing next_lane
---@param new_idx int
---@return Lane
function Lane:clone(new_idx)
    -- clone new_construct_range too
    local new_construct_range = {}
    for _, value in ipairs(self.construct_range) do
        table.insert(new_construct_range, value)
    end

    return Lane.new(
        self.item,
        self.name,
        self.direction,
        self.priority,
        new_idx,
        self.full_config,
        self.is_base_input,
        self.is_unused_lane,
        new_construct_range,
        nil
    )
end

---Is this a normal belt lane
---@return boolean
function Lane:is_normal_belt()
    return self.direction == LaneDirection.UP and
        self.priority == LanePriority.NORMAL and
        self:is_belt()
end

---Is this an output lane, includes unused items
---@return boolean
function Lane:is_output()
    return self.direction == LaneDirection.DOWN and
        self.priority == LanePriority.NORMAL
end

---Is this an input lane
---@return boolean
function Lane:is_input()
    return self.is_base_input
end

---Is this lane unused
---@return boolean
function Lane:is_unused()
    return self.is_unused_lane
end

---Is this lane a belt lane
---@return boolean
function Lane:is_belt()
    return self.item.item_type == ItemType.ITEM
end

---Is this lane a pipe lane
---@return boolean
function Lane:is_pipe()
    return self.item.item_type == ItemType.FLUID
end

---set the construct_range for this Lane
---Modifies self
---@param construct_range LaneStatus[]
function Lane:set_construct_range(construct_range)
    self.construct_range = construct_range
end

function Lane:tostring()
    return "Lane TODO"
end

---Create a diagram of this lane with the given height
---@param recipe_idx int index of current recipe, used to get LaneStatus
---@param min_y int
---@param max_y int
---@param taps int[] where taps are connected
---@param translation? int translate diagram
---@return Diagram
---@return LaneStatus
function Lane:draw_lane(recipe_idx, min_y, max_y, taps, translation)
    local full_lane = Empty.new()
    local status = self.construct_range[recipe_idx]
    if not LaneStatus.should_construct(status) then
        return full_lane, status
    end

    if status == LaneStatus.BOTH then
        error("LaneStatus.BOTH TODO")
    end

    -- fluids
    if self.lane_type == ItemType.FLUID then
        local start_lane = Empty.new()
        if status ~= LaneStatus.BEGIN then
            start_lane = Translate(0, max_y - 1, self.full_config.lane_data.PIPE_LANE_BEGIN)
        end
        local end_lane = Empty.new()
        if status ~= LaneStatus.END and status ~= LaneStatus.INPUT_END and
            status ~= LaneStatus.OUTPUT_BEGIN then
            end_lane = Translate(0, min_y, self.full_config.lane_data.PIPE_LANE_END)
        end
        return Translate(0, translation or 0, start_lane:compose(end_lane)), status
    end

    -- belts
    local lane_start = min_y
    local lane_stop = max_y

    -- ensure we have enough room for taps
    if status == LaneStatus.BEGIN and #taps > 0 then
        lane_stop = Array_max(taps) + 1
    end
    if (status == LaneStatus.END or status == LaneStatus.INPUT_END or
            status == LaneStatus.OUTPUT or status == LaneStatus.OUTPUT_BEGIN) and #taps > 0 then
        -- TODO check this
        lane_start = Array_min(taps) + 1
    end

    local lane_data = CoordTable.new()
    local entity = CoordTable.get(self.full_config.lane_data.BELT_LANE.primitive, 0, 0)
    if entity == nil then
        error("Could not find Entity")
    end
    if self.direction == LaneDirection.DOWN then
        entity = ActionPair.new(Entity.new(entity.data.name, EntityDirection.DOWN), nil)
    end

    -- now make the lane
    for idx = lane_start, lane_stop - 1 do
        CoordTable.set(lane_data, 0, idx, entity)
    end
    full_lane = Primitive.new(lane_data)
    if translation then
        full_lane = Translate(0, translation, full_lane)
    end

    -- now we have to compile it so that we can reverse belts in the future
    -- TODO improve this
    local compiled_lane = full_lane:compile()
    local final = Concat_primitives(compiled_lane)
    return Primitive.new(Primitives_to_actions(final)), status
end

---Finalize a lane: perform any final steps to the lane
---@param diagram Diagram
---@return Diagram
function Lane:finalize_lane(diagram)
    if self.lane_type == ItemType.ITEM then
        -- no finalization for belts
        return diagram
    end

    local envelope = diagram:envelope()
    if not envelope then
        -- emtpy diagram
        return diagram
    end

    local height = envelope.down + envelope.up + 1
    local primitive = Concat_primitives(diagram:compile())
    local fix_diagram = Empty.new()


    -- check that underground pipes can reach each other
    -- if not, add a template
    -- so we search for pipe-to-ground, direction north
    -- follow it south until we find the next pipe-to-ground of opposite
    -- direction

    CoordTable.iterate(primitive, function(x, y, entity)
        local entity_info = self.full_config.game_data.entities[entity.name]
        if not entity_info then
            return
        end
        if not (entity_info.type == "pipe-to-ground" and
                entity.direction == EntityDirection.UP) then
            return
        end

        local max_underground_distance = entity_info.max_underground_distance
        local loc = { x = x, y = y }
        for i = 1, height do
            loc = Follow_direction(EntityDirection.DOWN, loc)
            local new_entity = CoordTable.get(primitive, loc.x, loc.y)
            if new_entity then
                local new_entity_info = self.full_config.game_data.entities[new_entity.name]
                if new_entity_info and new_entity_info.type == "pipe-to-ground"
                    and new_entity.direction == EntityDirection.DOWN then
                    if i > max_underground_distance then
                        -- the next underground is too far away put in a fix
                        -- TODO multiple fixes?
                        fix_diagram = fix_diagram:compose(Translate(x, y + max_underground_distance - 1,
                            self.full_config.lane_data.PIPE_FIX))
                    end
                    -- if we reach here we have seen an underground pipe
                    -- so break
                    break
                end
            end
        end
    end)

    return diagram:compose(fix_diagram)
end

---Return a an array of signals representing this lane
---@return {type:string, name: string}[]
function Lane:lane_to_signal()
    local io_signal = nil
    if self.priority == LanePriority.HIGH then
        io_signal = "signal-H"
    elseif self.priority == LanePriority.LOW then
        io_signal = "signal-L"
    elseif self.direction == LaneDirection.DOWN then
        io_signal = "signal-D"
    elseif self:is_input() then
        io_signal = "signal-I"
    end
    local item_type = self.item.item_type
    if item_type == "fuel" then item_type = "item" end
    local output = { { type = item_type, name = self.item.name } }
    if io_signal ~= nil then
        table.insert(output, { type = "virtual", name = io_signal })
    end
    return output
end
