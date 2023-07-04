-- algorithms used in generating a bus
-- algorithms for building a factory

require("common.factory_components.bundle")
require("common.bus.flow_info")
require("common.bus.recipe_factory")

---Represents a collection of lanes
---@class LaneCollection : BaseClass
---@field lanes Lane[]
---@field lane_lookup table<string, table<int, int>>
LaneCollection = InheritsFrom(nil)

---Create a new LaneCollection
---@param lanes Lane[]
---@param lane_lookup table<string, table<int, int>>
---@return LaneCollection
function LaneCollection.new(lanes, lane_lookup)
    local self = LaneCollection:create()
    self.lanes = lanes
    self.lane_lookup = lane_lookup
    return self
end

---Get a Lane index from a LaneCollection
---@param name string
---@param priority LanePriority
---@return int
function LaneCollection:get_lane(name, priority)
    if self.lane_lookup[name] == nil then
        -- TODO proper support for fluid temperatures
        local new_name = string.match(name, "(.*)-%d+")
        if new_name == nil or self.lane_lookup[new_name] == nil then
            error("Could not find lane " .. name)
        end
    end
    return self.lane_lookup[name][priority]
end

---Get a Lane index from a LaneCollection, optional
---@param name string
---@param priority LanePriority
---@return int|nil
function LaneCollection:get_lane_optional(name, priority)
    if self.lane_lookup[name] == nil then
        return nil
    end
    return self.lane_lookup[name][priority]
end

---Get a lane by index
---@param idx int
---@return Lane
function LaneCollection:get_lane_by_idx(idx)
    return self.lanes[idx]
end

Algorithms = {}

---Generate all the lanes required
---@param full_recipe FullRecipe
---@param config FullConfig
---@return LaneCollection
function Algorithms.generate_lanes(full_recipe, config)
    local loc = 1
    ---@type Lane[]
    local lanes = {}
    ---@type table<string, table<int, int>>
    local lanes_lookup = {}
    local base_inputs = full_recipe:get_base_inputs()
    local unused_inputs = full_recipe:get_unused()

    local normal_up_lanes, normal_down_lanes = full_recipe:get_normal_lane_directions()
    local output_lane_direction = LaneDirection.DOWN
    if config.output_style == OutputStyle.up then
        output_lane_direction = LaneDirection.UP
    end
    local lane_generation_data = {
        {
            items = full_recipe:get_normal_output_items(),
            direction = LaneDirection.UP,
            priority = LanePriority
                .NORMAL
        },
        {
            items = full_recipe:get_outputs(),
            direction = output_lane_direction,
            priority = LanePriority
                .NORMAL
        },
        {
            items = full_recipe:get_unused(),
            direction = LaneDirection.DOWN,
            priority = LanePriority
                .NORMAL
        },
        { items = full_recipe:get_byproducts(),        direction = LaneDirection.UP,   priority = LanePriority.HIGH },
        { items = full_recipe:get_prioritized_items(), direction = LaneDirection.DOWN, priority = LanePriority.LOW },
        {
            items = normal_up_lanes,
            direction = LaneDirection.UP,
            priority = LanePriority
                .NORMAL_UP
        },
        {
            items = normal_down_lanes,
            direction = LaneDirection.DOWN,
            priority = LanePriority
                .NORMAL_DOWN
        }
    }
    for _, lane_data in ipairs(lane_generation_data) do
        for item_name, _ in pairs(lane_data.items) do
            local name = config.belt_item_name
            local item = full_recipe.item_lookup[item_name]
            if item == nil then
                error(string.format("Could not find item %s", item_name))
            end
            if item.item_type == ItemType.FLUID then
                name = config.pipe_item_name
            end
            if not config.fluids_only or item.item_type == ItemType.FLUID then
                table.insert(lanes, Lane.new(
                    item,
                    name,
                    lane_data.direction,
                    lane_data.priority,
                    loc,
                    config,
                    base_inputs[item.name] == true,
                    unused_inputs[item.name] == true
                ))
                if lanes_lookup[item.name] == nil then
                    lanes_lookup[item.name] = {}
                end
                lanes_lookup[item.name][lane_data.priority] = loc
                loc = loc + 1
            end
        end
    end
    return LaneCollection.new(lanes, lanes_lookup)
end

---Create the buffer recipes
---@param full_recipe FullRecipe
---@param fluids_only boolean
---@return RecipeInfo[]
function Algorithms.generate_buffers(full_recipe, fluids_only)
    ---@type RecipeInfo[]
    local buffers = {}
    for item_name, _ in pairs(Set.union(full_recipe:get_byproducts(), full_recipe:get_prioritized_items())) do
        local item = full_recipe.item_lookup[item_name]
        if not fluids_only or item.item_type == ItemType.FLUID then
            table.insert(buffers, RecipeInfo.new(
                Recipe.new(item.name .. "-buffer", { item }, { item }, 0.0, "buffer"),
                1,
                RecipeType.BUFFER,
                "",
                {},
                false,
                nil,
                {},
                { low = 0.0, normal = 0.0 },
                { normal = 0.0, high = 0.0 }
            ))
        end
    end
    return buffers
end

---@type table<string, table<int, int>>
local BUFFER_PORT_TYPE_TABLE = {
    [ItemType.FLUID] = {
        [LanePriority.HIGH] = PortType.FLUID_OUTPUT,
        [LanePriority.NORMAL_UP] = PortType.FLUID_OUTPUT,
        [LanePriority.NORMAL_DOWN] = PortType.FLUID_INPUT,
        [LanePriority.LOW] = PortType.FLUID_INPUT,
    },
    [ItemType.ITEM] = {
        [LanePriority.HIGH] = PortType.ITEM_OUTPUT,
        [LanePriority.NORMAL_UP] = PortType.ITEM_OUTPUT,
        [LanePriority.NORMAL_DOWN] = PortType.ITEM_INPUT,
        [LanePriority.LOW] = PortType.ITEM_INPUT,
    },
}

---Create all the BundlePorts to hook up bundles and recipes
---@param full_recipe FullRecipe
---@param lanes LaneCollection
---@param full_config FullConfig
---@return table<int, table<int, LanePort>>
function Algorithms.hook_up_lanes_and_recipes(full_recipe, lanes, full_config)
    ---@type table<int, table<int, LanePort>>
    local lane_ports = {}
    local byproducts = full_recipe:get_byproducts()
    local prioritized = full_recipe:get_prioritized_items()

    ---@type Set<string>
    local special_items = Set.union(byproducts, prioritized)
    -- priority rules:
    -- if the output is a prioritized item and the recipe type is produce, set LOW priority
    -- if the input is a byproduct item and the recipe type is consume, set HIGH priority

    for recipe_idx, recipe_info in ipairs(full_recipe.recipes) do
        if recipe_info.recipe_type == RecipeType.BUFFER then
            -- special case for buffers
            local item = recipe_info.recipe.inputs[1]
            for _, priority in pairs(LanePriority) do
                if priority == LanePriority.NORMAL then
                    -- skip this since it is replaced by normal up or down
                else
                    local lane_idx = lanes:get_lane_optional(item.name, priority)
                    if lane_idx ~= nil then
                        local port_type = BUFFER_PORT_TYPE_TABLE[item.item_type][priority]
                        if port_type == nil then
                            error("Port type is nil")
                        end
                        if lane_ports[lane_idx] == nil then
                            lane_ports[lane_idx] = {}
                        end
                        lane_ports[lane_idx][recipe_idx] = LanePort.new(
                            lane_idx,
                            item.name,
                            port_type,
                            DEFAULT_PORT_INDEX,
                            priority
                        )
                    end
                end
            end
        else
            --- normal case for non-buffers
            local item_idx = 0 -- 0-indexed in game
            for _, item in ipairs(recipe_info.recipe.inputs) do
                if not full_config.fluids_only or item.item_type == ItemType.FLUID then
                    local priority = LanePriority.NORMAL
                    if recipe_info.recipe_type == RecipeType.CONSUME and
                        byproducts[item.name] == true then
                        priority = LanePriority.HIGH
                    elseif special_items[item.name] == true then
                        priority = LanePriority.NORMAL_UP
                    end
                    local port_type = PortType.ITEM_INPUT
                    ---@type int|nil
                    local idx = item_idx
                    if item.item_type == ItemType.FLUID then
                        port_type = PortType.FLUID_INPUT
                        idx = item.fluidbox_index
                    elseif item.item_type == ItemType.FUEL then
                        port_type = PortType.FUEL
                    else
                        item_idx = item_idx + 1
                    end
                    local lane_idx = lanes:get_lane(item.name, priority)
                    if lane_idx == nil then
                        error("Cannot find lane for " .. item.name .. " with priority " .. priority)
                    end

                    -- normally only connecto to normal priority ports,
                    -- buffers are handled differently
                    if lane_ports[lane_idx] == nil then
                        lane_ports[lane_idx] = {}
                    end
                    if recipe_info.inputs[item.name] and recipe_info.inputs[item.name] > 0 then
                        lane_ports[lane_idx][recipe_idx] = LanePort.new(
                            lane_idx,
                            item.name,
                            port_type,
                            idx,
                            LanePriority.NORMAL,
                            recipe_info.inputs[item.name]
                        )
                    else
                        -- probably a loop
                        -- print(string.format("Recipe %s item %s has no input flow", recipe_info.recipe.name, item.name))
                    end
                end
            end
            --- now for ouputs
            local item_idx = 0 -- 0-indexed in game
            for _, item in ipairs(recipe_info.recipe.outputs) do
                if not full_config.fluids_only or item.item_type == ItemType.FLUID then
                    local priority = LanePriority.NORMAL
                    if recipe_info.recipe_type == RecipeType.PRODUCE and
                        prioritized[item.name] == true then
                        priority = LanePriority.LOW
                    elseif special_items[item.name] == true then
                        priority = LanePriority.NORMAL_DOWN
                    end
                    local port_type = PortType.ITEM_OUTPUT
                    ---@type int|nil
                    local idx = item_idx
                    if item.item_type == ItemType.FLUID then
                        port_type = PortType.FLUID_OUTPUT
                        idx = item.fluidbox_index
                    else
                        item_idx = item_idx + 1
                    end
                    local lane_idx = lanes:get_lane(item.name, priority)
                    if not (lanes.lanes[lane_idx]:is_output() and not OutputStyle.generate_output_lane(full_config.output_style)) then
                        -- normally only connect to to normal priority ports,
                        -- buffers are handled differently
                        if lane_ports[lane_idx] == nil then
                            lane_ports[lane_idx] = {}
                        end
                        if recipe_info.outputs[item.name] and recipe_info.outputs[item.name] > 0 then
                            lane_ports[lane_idx][recipe_idx] = LanePort.new(
                                lane_idx,
                                item.name,
                                port_type,
                                idx,
                                LanePriority.NORMAL,
                                recipe_info.outputs[item.name]
                            )
                        else
                            -- probably a loop
                            -- print(string.format("Recipe %s item %s has no output flow", recipe_info.recipe.name, item.name))
                        end
                    end
                end
            end
        end
    end

    return lane_ports
end

---Calculate the flowrate of the initial part of the bus
---@param full_recipe FullRecipe
---@param lanes LaneCollection
---@param full_config FullConfig
---@return FullFlowInfo
function Algorithms.calculate_initial_flowrate(full_recipe, lanes, full_config)
    local flowrate = FullFlowInfo.new(lanes.lanes, full_recipe)
    local num_recipes = #full_recipe.recipes

    -- we sart at the bottom, taking the initial flow rates
    -- then we work upwards, copying from the previous line to the final line
    -- ignore output and special lanes

    ---internal function
    ---@param item_name string
    ---@param item_flowrate float
    local function process(item_name, item_flowrate)
        local idx = lanes:get_lane(item_name, LanePriority.NORMAL)
        if idx == nil then
            idx = lanes:get_lane(item_name, LanePriority.NORMAL_UP)
            if idx == nil then
                error(string.format("Cannot find lane for %s with flowrate %f", item_name, item_flowrate))
            end
        end
        local lane = lanes:get_lane_by_idx(idx)
        if lane:is_pipe() then
            -- TODO: finish this
            if flowrate.data[idx] == nil then
                flowrate.data[idx] = {}
            end
            if lane:is_output() then
                item_flowrate = -1 * item_flowrate
            end
            flowrate.data[idx][num_recipes] = FlowInfo.new(
                full_recipe.timescale, item_flowrate, item_flowrate, item_flowrate
            )
        else
            local remaining_flow = item_flowrate
            local max_flow_rate = (
                full_config.game_data.transport_belt_speeds[lane.name]
                * full_recipe.timescale
                * full_config.max_bundle_size
            )
            while remaining_flow > 0 do
                local next_lane = lane.next_lane
                local next_flow
                if next_lane == nil then
                    next_flow = remaining_flow
                else
                    next_flow = math.min(max_flow_rate, remaining_flow)
                end
                remaining_flow = remaining_flow - next_flow
                if lane:is_output() and full_config.output_style == OutputStyle.down then
                    next_flow = -1 * next_flow
                end
                if flowrate.data[lane.idx] == nil then
                    flowrate.data[lane.idx] = {}
                end
                flowrate.data[lane.idx][num_recipes] = FlowInfo.new(
                    full_recipe.timescale, next_flow, next_flow, next_flow
                )
                if next_lane == nil then
                    break
                end
                lane = next_lane
            end
        end
    end

    for item_name, item_flowrate in pairs(full_recipe.inputs) do
        if not full_config.fluids_only or full_config.game_data.fluids[item_name] ~= nil then
            process(item_name, item_flowrate)
        end
    end
    for item_name, _ in pairs(full_recipe:get_outputs_that_are_not_used_as_inputs()) do
        local item_flowrate = full_recipe.outputs[item_name]
        if (not full_config.fluids_only or full_config.game_data.fluids[item_name] ~= nil) and full_config.output_style == OutputStyle.down then
            process(item_name, item_flowrate)
        end
    end

    flowrate:round_values()
    return flowrate
end

---Processing of lanes and recipes to work out flowrates
---@param full_recipe FullRecipe
---@param lanes LaneCollection
---@param lane_ports table<int, table<int, LanePort>>
---@param config FullConfig
---@return FullFlowInfo
function Algorithms.calculate_flowrate(full_recipe, lanes, lane_ports, config)
    local flowrate = FullFlowInfo.new(lanes.lanes, full_recipe)
    local num_recipes = #full_recipe.recipes

    -- we sart at the bottom, taking the initial flow rates
    -- then we work upwards, copying from the previous line to the final line
    -- ignore output and special lanes
    for item_name, item_flowrate in pairs(full_recipe.inputs) do
        if not config.fluids_only or config.game_data.fluids[item_name] ~= nil then
            local idx = lanes:get_lane(item_name, LanePriority.NORMAL)
            local lane = lanes:get_lane_by_idx(idx)
            if idx == nil then
                idx = lanes:get_lane(item_name, LanePriority.NORMAL_UP)
                if idx == nil then
                    error(string.format("Index is nil: %s, %s [%s]", item_name, Dump(item_flowrate),
                        Dump(full_recipe.inputs)))
                end
            end
            if flowrate.data[idx] == nil then
                flowrate.data[idx] = {}
            end
            flowrate.data[idx][num_recipes] = FlowInfo.new(full_recipe.timescale, item_flowrate, item_flowrate,
                item_flowrate)
        end
    end

    local num = #full_recipe.recipes

    for idx = 1, num do
        local current_idx = num - idx + 1
        local recipe = full_recipe.recipes[current_idx]
        -- copy previous line
        for lane_idx, data in pairs(flowrate.data) do
            local recipe_idx = current_idx + 1
            local flow_info = data[recipe_idx]
            if flow_info ~= nil then
                local lane_priority = lanes:get_lane_by_idx(lane_idx).priority
                if lane_priority == LanePriority.NORMAL or lane_priority == LanePriority.NORMAL_UP then
                    if flowrate.data[lane_idx] == nil then
                        flowrate.data[lane_idx] = {}
                    end
                    if flowrate.data[lane_idx][current_idx] == nil then
                        flowrate.data[lane_idx][current_idx] = FlowInfo.new(full_recipe.timescale, 0, 0, 0)
                    end
                    local to_update = flowrate.data[lane_idx][current_idx]
                    to_update.lower_flow = to_update.lower_flow + flow_info.upper_flow
                    to_update.middle_flow = to_update.middle_flow + flow_info.upper_flow
                    to_update.upper_flow = to_update.upper_flow + flow_info.upper_flow
                end
            end
        end

        for lane_idx, port_data in pairs(lane_ports) do
            local idx = current_idx
            local port = port_data[idx]
            if port ~= nil then
                local lane = lanes:get_lane_by_idx(lane_idx)
                if flowrate.data[lane_idx] == nil then
                    flowrate.data[lane_idx] = {}
                end
                if flowrate.data[lane_idx][current_idx] == nil then
                    flowrate.data[lane_idx][current_idx] = FlowInfo.new(full_recipe.timescale, 0, 0, 0)
                end
                if lane:is_output() then
                    flowrate.data[lane_idx][current_idx].middle_flow = flowrate.data[lane_idx][current_idx]
                        .middle_flow - port.flow_rate
                else
                    local multiplier = 1
                    local prioritized = false
                    if port.port_type == PortType.ITEM_INPUT or
                        port.port_type == PortType.FLUID_INPUT or
                        port.port_type == PortType.FUEL then
                        multiplier = -1
                    end
                    if lane.priority == LanePriority.HIGH then
                        multiplier = 1
                        prioritized = true
                    elseif lane.priority == LanePriority.LOW or
                        lane.priority == LanePriority.NORMAL_DOWN then
                        multiplier = -1
                        prioritized = true
                    end

                    -- TODO sort this out

                    if (port.port_type == PortType.FLUID_INPUT or port.port_type == PortType.ITEM_INPUT)
                        and not prioritized then
                        flowrate.data[lane_idx][current_idx].middle_flow = flowrate.data[lane_idx][current_idx]
                            .middle_flow +
                            multiplier * port.flow_rate
                    end
                    if prioritized and lane.priority ~= LanePriority.HIGH then
                        flowrate.data[lane_idx][current_idx].middle_flow = flowrate.data[lane_idx][current_idx]
                            .middle_flow +
                            multiplier * port.flow_rate
                    elseif prioritized and lane.priority == LanePriority.HIGH then
                        flowrate.data[lane_idx][current_idx].lower_flow = flowrate.data[lane_idx][current_idx]
                            .lower_flow +
                            multiplier * port.flow_rate
                    else
                        flowrate.data[lane_idx][current_idx].upper_flow = flowrate.data[lane_idx][current_idx]
                            .upper_flow +
                            multiplier * port.flow_rate
                    end
                end
            end
        end
    end

    -- Debug.save_flowrate(full_recipe.recipes, lanes, flowrate.data, nil, nil, "temp")


    -- now, from the top down, find the prioritized items and copy them downards until
    -- we hit their buffers
    -- LOW and NORMAL_DOWN flow to mid, HIGH flows down to upper only
    -- prioritized_lanes: list[tuple[int, Item, LanePriority]] = [
    --     (lane_idx, lane.item, lane.priority)
    --     for lane_idx, lane in enumerate(lanes.lanes)
    --     if lane.priority
    --     in [LanePriority.LOW, LanePriority.HIGH, LanePriority.NORMAL_DOWN]
    -- ]
    ---@type Set<int>
    local finished_lanes = {}
    ---@type {recipe_idx: int, item: Item}[]
    local buffer_locations = {}
    ---@type Set<int>
    local seen_buffers = {}
    for recipe_idx, recipe in ipairs(full_recipe.recipes) do
        for lane_idx, lane in ipairs(lanes.lanes) do
            if lane.priority == LanePriority.LOW or
                lane.priority == LanePriority.HIGH or
                lane.priority == LanePriority.NORMAL_DOWN then
                local coord = lane_idx
                local item = lane.item
                local priority = lane.priority

                if finished_lanes[coord] ~= true then
                    if flowrate.data[lane_idx] == nil then
                        flowrate.data[lane_idx] = {}
                    end
                    if flowrate.data[lane_idx][recipe_idx] == nil then
                        flowrate.data[lane_idx][recipe_idx] = FlowInfo.new(full_recipe.timescale, 0, 0, 0)
                    end

                    if recipe_idx > 1 then
                        flowrate.data[coord][recipe_idx].upper_flow = flowrate.data[coord][recipe_idx].upper_flow +
                            flowrate.data[coord][recipe_idx - 1].lower_flow
                    end

                    -- is this the buffer?
                    if (
                            recipe.recipe_type == RecipeType.BUFFER
                            and recipe.recipe.inputs[1].name == item.name
                        ) then
                        if not seen_buffers[recipe_idx] == true then
                            table.insert(buffer_locations, { recipe_idx = recipe_idx, item = item })
                            seen_buffers[recipe_idx] = true
                        end
                        finished_lanes[coord] = true

                        if priority == LanePriority.LOW or priority == LanePriority.NORMAL_DOWN then
                            -- also flow down to middle
                            flowrate.data[coord][recipe_idx].middle_flow = flowrate.data[coord][recipe_idx].middle_flow +
                                flowrate.data[coord][recipe_idx].upper_flow
                        end
                    else
                        flowrate.data[coord][recipe_idx].middle_flow = flowrate.data[coord][recipe_idx].middle_flow +
                            flowrate.data[coord][recipe_idx].upper_flow
                        flowrate.data[coord][recipe_idx].lower_flow = flowrate.data[coord][recipe_idx].lower_flow +
                            flowrate.data[coord][recipe_idx].middle_flow
                    end
                end
            end
        end
    end
    -- finally, for each buffer, find out how much normal we have left (low - high),
    -- then copy that upwards.
    -- Debug.save_flowrate(full_recipe.recipes, lanes, flowrate.data, nil, nil, "temp2")

    for _, buffer_loc in pairs(buffer_locations) do
        local recipe_idx = buffer_loc.recipe_idx
        local item = buffer_loc.item
        local normal_up_coord = lanes:get_lane_optional(item.name, LanePriority.NORMAL_UP)
        if normal_up_coord ~= nil then
            local normal_down_coord = lanes:get_lane_optional(item.name, LanePriority.NORMAL_DOWN)
            local high_coord = lanes:get_lane_optional(item.name, LanePriority.HIGH)
            local low_coord = lanes:get_lane_optional(item.name, LanePriority.LOW)

            local high_pri_value, low_pri_value, normal_pri_value
            if high_coord == nil then
                high_pri_value = 0.0
            else
                high_pri_value = flowrate.data[high_coord][recipe_idx].upper_flow
            end
            if low_coord == nil then
                low_pri_value = 0.0
            else
                low_pri_value = flowrate.data[low_coord][recipe_idx].upper_flow
            end
            if normal_down_coord == nil then
                normal_pri_value = 0.0
            else
                normal_pri_value = flowrate.data[normal_down_coord][recipe_idx].upper_flow
            end

            -- update normal lane with remaining from buffer
            flowrate.data[normal_up_coord][recipe_idx].upper_flow = flowrate.data[normal_up_coord][recipe_idx]
                .upper_flow - (
                    low_pri_value + high_pri_value + normal_pri_value
                )
            -- flow it up to the top
            for idx = 1, recipe_idx - 1 do
                flowrate.data[normal_up_coord][idx].lower_flow = flowrate.data[normal_up_coord][idx]
                    .lower_flow - (
                        low_pri_value + high_pri_value + normal_pri_value
                    )
                flowrate.data[normal_up_coord][idx].middle_flow = flowrate.data[normal_up_coord][idx]
                    .middle_flow - (
                        low_pri_value + high_pri_value + normal_pri_value
                    )
                flowrate.data[normal_up_coord][idx].upper_flow = flowrate.data[normal_up_coord][idx]
                    .upper_flow - (
                        low_pri_value + high_pri_value + normal_pri_value
                    )
            end
        end
    end
    -- Debug.save_flowrate(full_recipe.recipes, lanes, flowrate.data, nil, nil, "temp3")

    -- work on output lanes
    for lane_idx, lane in ipairs(lanes.lanes) do
        if flowrate.data[lane_idx] == nil then
            flowrate.data[lane_idx] = {}
        end
        if lane:is_output() and config.output_style == OutputStyle.down then
            for recipe_idx = 1, num_recipes do
                if flowrate.data[lane_idx][recipe_idx] == nil then
                    flowrate.data[lane_idx][recipe_idx] = FlowInfo.new(full_recipe.timescale, 0, 0, 0)
                end
                if recipe_idx > 1 then
                    flowrate.data[lane_idx][recipe_idx].upper_flow = flowrate.data[lane_idx][recipe_idx].upper_flow +
                        flowrate.data[lane_idx][recipe_idx - 1].lower_flow
                end
                flowrate.data[lane_idx][recipe_idx].middle_flow = flowrate.data[lane_idx][recipe_idx].middle_flow +
                    flowrate.data[lane_idx][recipe_idx].upper_flow
                flowrate.data[lane_idx][recipe_idx].lower_flow = flowrate.data[lane_idx][recipe_idx].lower_flow +
                    flowrate.data[lane_idx][recipe_idx].middle_flow
            end
        end
    end

    -- clear out anything too small
    flowrate:round_values()
    return flowrate
end

local eps = 1e-6

---For each lane set its construction range
---@param full_recipe FullRecipe
---@param lanes LaneCollection
---@param flowrate FullFlowInfo
function Algorithms.set_lane_usage(full_recipe, lanes, flowrate)
    local num_recipes = #full_recipe.recipes
    for lane_idx, lane in ipairs(lanes.lanes) do
        if lane:is_unused() then
            local list = {}
            for _ = 1, num_recipes do
                table.insert(list, LaneStatus.BYPRODUCT)
            end
            lane:set_construct_range(list)
        else
            ---@type LaneStatus[]
            local construction_info = {}
            if lane:is_output() then
                local recipe_idx = 1
                while (
                        recipe_idx <= num_recipes
                        and math.abs(flowrate.data[lane_idx][recipe_idx].lower_flow) < eps
                        and math.abs(flowrate.data[lane_idx][recipe_idx].upper_flow) < eps
                    ) do
                    table.insert(construction_info, LaneStatus.EMPTY)
                    recipe_idx = recipe_idx + 1
                end
                table.insert(construction_info, LaneStatus.OUTPUT_BEGIN)
                for _ = 1, num_recipes - recipe_idx do
                    table.insert(construction_info, LaneStatus.OUTPUT)
                end
            else
                for recipe_idx = 1, num_recipes do
                    if math.abs(flowrate.data[lane_idx][recipe_idx].upper_flow) < eps then
                        if math.abs(flowrate.data[lane_idx][recipe_idx].lower_flow) < eps then
                            table.insert(construction_info, LaneStatus.EMPTY)
                        else
                            table.insert(construction_info, LaneStatus.END)
                        end
                    else
                        if math.abs(flowrate.data[lane_idx][recipe_idx].lower_flow) < eps then
                            table.insert(construction_info, LaneStatus.BEGIN)
                        else
                            table.insert(construction_info, LaneStatus.CONSTRUCT)
                        end
                    end
                end
                -- at then end check for inputs:
                if lane:is_input() then
                    if construction_info[#construction_info] == LaneStatus.END then
                        construction_info[#construction_info] = LaneStatus.INPUT_END
                    else
                        construction_info[#construction_info] = LaneStatus.INPUT
                    end
                end
            end
            lane:set_construct_range(construction_info)
        end
    end
end

---Groups lanes into bundles
---@param lanes LaneCollection
---@param coloring int[]
---@param lane_ports table<int, table<int, LanePort>>
---@param flowrate FullFlowInfo
---@param config FullConfig
---@return OverlappingBundle[]
---@return table<int, table<int, table<int, BundlePort>>>
function Algorithms.generate_bundles(lanes, coloring, lane_ports, flowrate, config)
    local num_lanes = #lanes.lanes
    ---@type Bundle[]
    local bundles = {}
    ---@type OverlappingBundle[]
    local overlapping_bundles = {}

    ---@type table<int, table<int, table<int, BundlePort>>>
    local bundle_ports = {}
    -- keep track of lanes to bundles
    ---@type table<int, {bundle:int, lane:int}>
    local lane_bundle_coord = {}

    ---@type int[]
    local max_lanes_required = {}
    for _ = 1, #lanes.lanes do table.insert(max_lanes_required, 0) end

    for lane_idx, data in pairs(flowrate.data) do
        for recipe_idx, flowinfo in pairs(data) do
            local lane = lanes:get_lane_by_idx(lane_idx)
            max_lanes_required[lane_idx] = math.max(
                flowinfo:get_number_of_lanes_needed(config),
                max_lanes_required[lane_idx]
            )
        end
    end

    local lane_idx = 1
    -- local bundle_idx = 1
    while lane_idx <= num_lanes do
        local lane = lanes:get_lane_by_idx(lane_idx)

        if not (lane:is_output() and not OutputStyle.generate_output_lane(config.output_style)) then
            -- game.print(string.format("Lane idx %d for %s", lane_idx, lane.item.name))
            local color = coloring[lane_idx]
            -- if (
            --         max_lanes_required[lane_idx] == 1
            --         and lane_idx < num_lanes
            --         and max_lanes_required[lane_idx + 1] == 1
            --     ) then
            --     local even_lane = lane
            --     local odd_lane = lanes:get_lane_by_idx(lane_idx + 1)
            --     table.insert(bundles,
            --         TwoLaneHeterogeneousBundle.create_two_lane_bundle(even_lane, odd_lane, config)
            --     )
            --     lane_bundle_coord[lane_idx] = { bundle = bundle_idx, lane = 1 }
            --     lane_bundle_coord[lane_idx + 1] = { bundle = bundle_idx, lane = 2 }
            --     lane_idx = lane_idx + 2
            --     bundle_idx = bundle_idx + 1
            -- else
            local bundle = MultiLaneBundle.new(lane, max_lanes_required[lane_idx], config)
            table.insert(bundles, bundle)
            if overlapping_bundles[color] == nil then
                overlapping_bundles[color] = OverlappingBundle.new()
            end
            table.insert(overlapping_bundles[color].bundles, bundle)
            lane_bundle_coord[lane_idx] = { bundle = color, lane = #overlapping_bundles[color].bundles }
            -- bundle_idx = bundle_idx + 1
            --TODO pipe support
            -- end
        end
        lane_idx = lane_idx + 1
    end

    -- convert LanePorts to BundlePorts:
    for lane_idx, data in pairs(lane_ports) do
        for recipe_idx, port in pairs(data) do
            local full_coordinate = lane_bundle_coord[lane_idx]
            if bundle_ports[full_coordinate.bundle] == nil then
                bundle_ports[full_coordinate.bundle] = {}
            end
            if bundle_ports[full_coordinate.bundle][full_coordinate.lane] == nil then
                bundle_ports[full_coordinate.bundle][full_coordinate.lane] = {}
            end
            bundle_ports[full_coordinate.bundle][full_coordinate.lane][recipe_idx] = port:to_bundle_port(
                full_coordinate.bundle, full_coordinate.lane
            )
        end
    end

    return overlapping_bundles, bundle_ports
end

---Generate Bypasses
---@param bundle_ports table<int, table<int, table<int, BundlePort>>>
---@return table<int, BundleBypass[]>
function Algorithms.generate_bypasses(bundle_ports)
    ---@type table<int, BundleBypass[]>
    local bypasses = {}
    for _, data1 in pairs(bundle_ports) do
        for _, data2 in pairs(data1) do
            for recipe_idx, bundle_port in pairs(data2) do
                for bypass_idx = 1, bundle_port.bundle_idx - 1 do
                    local new_bypass = bundle_port:to_bypass(bypass_idx)
                    local current_bypasses = bypasses[recipe_idx]
                    if current_bypasses == nil then
                        current_bypasses = {}
                    end
                    table.insert(current_bypasses, new_bypass)
                    bypasses[recipe_idx] = current_bypasses
                end
            end
        end
    end

    return bypasses
end

---Return if the first array of fluidboxes is contained in the second fluidbox lookup
---@param required table<int, Fluidbox>
---@param target table<int, Fluidbox>
---@return boolean
local function compare_fluidboxes(required, target)
    for _, fluidbox in pairs(required) do
        if target == nil then
            return false
        end
        local lookup = target[fluidbox.index]
        if lookup == nil then
            return false
        end
        if lookup.x ~= fluidbox.x or lookup.y ~= fluidbox.y or lookup.type ~= fluidbox.type then
            return false
        end
    end

    return true
end

---Choose a template given a recipe
---@param recipe RecipeInfo
---@param full_config FullConfig
---@returns Template
function Algorithms.choose_template(recipe, full_config)
    ---@type {template: Template|nil, priority: number, template_builder: function|nil}[]
    local templates = {}
    local buffer_type, min_item_inputs, min_item_outputs, min_fluid_inputs, min_fluid_outputs, custom_recipe, num_machines, min_item_loops, min_fluid_loops
    local entity = full_config.game_data.entities[recipe.machine_name]
    local height, width, fluidboxes
    local required_fluidboxes = {}
    if entity then
        height = entity.tile_height
        width = entity.tile_width
        fluidboxes = full_config.game_data:get_fluidboxes_for_entity(recipe.machine_name)
        local fluidbox_lookup = {}
        for _, fluidbox in ipairs(fluidboxes or {}) do
            fluidbox_lookup[fluidbox.index] = fluidbox
        end

        local recipe_fluidboxes = recipe.recipe:get_fluidboxes()

        -- now we filter the fluidboxes to the required ones
        for _, fluidbox in ipairs(recipe_fluidboxes) do
            table.insert(required_fluidboxes, fluidbox_lookup[fluidbox.global_index])
        end
    end
    -- if height == 0 then height = nil end
    -- if width == 0 then width = nil end

    ---Filter an array by ItemType
    ---@param array IngredientItem[]
    ---@param item_type ItemType
    ---@return integer
    local function filter_count(array, item_type)
        local out = 0
        for _, entry in pairs(array) do
            if entry.item_type == item_type then
                out = out + 1
            end
        end
        return out
    end

    if recipe.recipe_type == RecipeType.BUFFER then
        buffer_type = recipe.recipe.inputs[1].item_type
    elseif recipe.custom_recipe then
        custom_recipe = recipe.recipe.name
    else
        min_item_inputs = filter_count(recipe.recipe.inputs, ItemType.ITEM)
        min_fluid_inputs = filter_count(recipe.recipe.inputs, ItemType.FLUID)
        min_item_outputs = filter_count(recipe.recipe.outputs, ItemType.ITEM)
        min_fluid_outputs = filter_count(recipe.recipe.outputs, ItemType.FLUID)
        min_item_loops = filter_count(recipe.recipe.loops, ItemType.ITEM)
        min_fluid_loops = filter_count(recipe.recipe.loops, ItemType.FLUID)
        num_machines = recipe.machine_count
        if full_config.ignore_recipe_loops then
            min_fluid_loops = 0
            min_item_loops = 0
        end
    end

    for _, data in pairs(full_config.template_data) do
        if buffer_type then
            if buffer_type == data.metadata.buffer then
                table.insert(templates,
                    {
                        template = data.template,
                        priority = data.metadata.priority,
                        template_builder = data.template_builder
                    })
            end
        elseif custom_recipe and full_config.custom_recipes_enabled then
            if custom_recipe == data.metadata.custom_recipe then
                table.insert(templates,
                    {
                        template = data.template,
                        priority = data.metadata.priority,
                        template_builder = data.template_builder
                    })
            end
        else
            -- work out if we have all mods for this template
            local have_all_required_mods = true
            local required_mods = data.metadata.mods
            if required_mods then
                for mod_name, _ in pairs(required_mods) do
                    if game and game.active_mods[mod_name] == nil then
                        have_all_required_mods = false
                    end
                end
            end
            if have_all_required_mods and data.metadata and
                data.metadata.item_inputs >= min_item_inputs and
                data.metadata.item_outputs >= min_item_outputs and
                data.metadata.fluid_inputs >= min_fluid_inputs and
                data.metadata.fluid_outputs >= min_fluid_outputs and
                data.metadata.item_loops >= min_item_loops and
                data.metadata.fluid_loops >= min_fluid_loops and
                (data.metadata.num_machines == nil or num_machines <= data.metadata.num_machines) and
                (data.metadata.size_generic or (height and data.metadata.machine_heights and data.metadata.machine_heights[height])) and
                (data.metadata.size_generic or (width and data.metadata.machine_widths and data.metadata.machine_widths[width])) and
                (data.metadata.fluidbox_generic or compare_fluidboxes(required_fluidboxes, data.metadata.fluidboxes)) and
                (full_config.allow_logistic or not data.metadata.uses_logistic_network) then
                table.insert(templates,
                    {
                        template = data.template,
                        priority = data.metadata.priority,
                        template_builder = data.template_builder
                    })
            end
        end
    end

    local data_table = {
        recipe = recipe.recipe.name,
        custom_recipe = custom_recipe,
        min_fluid_inputs = min_fluid_inputs,
        min_fluid_outputs = min_fluid_outputs,
        min_fluid_loops = min_fluid_loops,
        min_item_inputs = min_item_inputs,
        min_item_outputs = min_item_outputs,
        min_item_loops = min_item_loops,
        machine_height = height,
        machine_width = width,
        num_machines = num_machines,
    }

    if Table_empty(templates) then
        full_config.bus_debug_logger:save_recipe_choice(recipe.recipe.name, "Default Template", data_table)
        -- print(string.format("Could not find template so creating default.  Data: %s", Dump(data_table)))
        full_config.logger:warn(
            "Could not find a template for recipe %s so using the Default Template.\nThis will need manual construction.",
            recipe.recipe.name)
        return Template.default_template(data_table, recipe, full_config)
    end

    table.sort(templates, function(x, y) return x.priority > y.priority end)
    if templates[1].template then
        full_config.bus_debug_logger:save_recipe_choice(recipe.recipe.name, templates[1].template.name, data_table)
        return templates[1].template
    else
        local template = templates[1].template_builder(recipe, full_config)
        full_config.bus_debug_logger:save_recipe_choice(recipe.recipe.name, template.name, data_table)
        full_config.logger:info("Chosen template %s for recipes %s", template.name, recipe.recipe.name)
        return template
    end
end

---Generate factories
---@param full_recipe FullRecipe
---@param bundles OverlappingBundle[]
---@param bundle_ports table<int, table<int, table<int, BundlePort>>>
---@param bypasses table<int, Bypass[]>
---@param full_config FullConfig
---@return RecipeFactory[]
function Algorithms.generate_factories(full_recipe, bundles, bundle_ports, bypasses, full_config)
    ---@type RecipeFactory[]
    local output = {}

    for recipe_idx, recipe in ipairs(full_recipe.recipes) do
        local template = Algorithms.choose_template(recipe, full_config)
        if not template then
            error(string.format("Could not choose template for recipe %s", recipe))
        end
        local flow_rates = recipe.inputs
        local clocked_template = ClockedTemplate.new(
            template, flow_rates, full_recipe.timescale
        )
        ---@type BundlePort[]
        local ports = {}
        for _, data1 in pairs(bundle_ports) do
            for _, data2 in pairs(data1) do
                local bundle_port = data2[recipe_idx]
                if bundle_port ~= nil then
                    table.insert(ports, bundle_port)
                end
            end
        end

        table.insert(output,
            RecipeFactory.new(
                recipe,
                recipe_idx,
                clocked_template,
                ports,
                bundles,
                bypasses[recipe_idx] or {},
                full_config
            )
        )
    end
    return output
end

---Split any lanes that are too big for a bundle
---@param full_recipe FullRecipe
---@param lanes LaneCollection
---@param flowrate FullFlowInfo
---@param full_config FullConfig
---@return LaneCollection
function Algorithms.split_lanes(full_recipe, lanes, flowrate, full_config)
    local loc = #lanes.lanes
    -- copy the lanes since we will be modifying the original
    local current_lanes = Copy(lanes.lanes)
    for lane_idx, lane in ipairs(current_lanes) do
        if lane:is_pipe() then
            -- TODO support pipes
        else
            -- # calculate max number of belts
            local max_belts = 0.0
            for recipe_idx = 1, #full_recipe.recipes do
                local belts_needed = flowrate.data[lane_idx][recipe_idx]:get_number_of_belts_needed(full_config)[
                full_config.belt_item_name
                ]
                max_belts = math.max(max_belts, belts_needed.lower, belts_needed.middle, belts_needed.upper)
            end

            local num_extra_lanes_required = math.ceil(max_belts / full_config.max_bundle_size) - 1
            if num_extra_lanes_required > 0 then
                local prev_lane = lane
                for _ = 1, num_extra_lanes_required do
                    loc = loc + 1
                    local new_lane = lane:clone(loc)
                    prev_lane:set_next_lane(new_lane)
                    table.insert(lanes.lanes, new_lane)
                    prev_lane = new_lane
                end
            end
        end
    end

    return lanes
end

---Split recipes that have too many lanes flowing into them or
--- the input bundle is empty.
---Note: this reverses the recipe list, since we start at the bottom
---@param full_recipe FullRecipe
---@param lanes LaneCollection
---@param lane_ports table<int, table<int, LanePort>>
---@param flowrate FullFlowInfo
---@param full_config FullConfig
---@return FullRecipe
---@return table<int, table<int, LanePort>>
---@return FullFlowInfo
function Algorithms.split_recipes(full_recipe, lanes, lane_ports, flowrate, full_config)
    -- To debug:
    -- full_config.bus_debug_logger:Debug_save_flowrate(new_recipes, lanes, new_flowrate_data, True)
    ---@type RecipeInfo[]
    local new_recipes = {}
    ---@type table<int, table<int, LanePort>>
    local new_lane_ports = {}
    ---@type table<int, table<int, FlowInfo>>
    local new_flowrate_data = {}
    local new_recipe_idx = 1 -- this increases by 1 for every new recipe we add

    -- initialize local variables
    for lane_idx = 1, #lanes.lanes do
        new_lane_ports[lane_idx] = {}
        new_flowrate_data[lane_idx] = {}
    end

    -- set initial flowrates
    for lane_idx = 1, #lanes.lanes do
        local flow = flowrate.data[lane_idx][flowrate.num_recipes].lower_flow
        new_flowrate_data[lane_idx][1] = FlowInfo.new(
            full_recipe.timescale, flow, flow, flow
        )
    end
    -- go through the recipes in reverse order
    for recipe_idx = #full_recipe.recipes, 1, -1 do
        local recipe = full_recipe.recipes[recipe_idx]

        -- This is used multiple times
        ---@type {lane_idx: int, lane: Lane, port: LanePort}[]
        local recipe_lane_ports = {}
        for lane_idx, data in pairs(lane_ports) do
            local port = data[recipe_idx]
            if port ~= nil then
                table.insert(recipe_lane_ports,
                    { lane_idx = lane_idx, lane = lanes:get_lane_by_idx(lane_idx), port = port })
            end
        end

        -- TODO: split buffers
        if recipe.recipe_type == RecipeType.BUFFER then
            -- new lane ports
            for _, data in pairs(recipe_lane_ports) do
                local lane_idx, lane, port = data.lane_idx, data.lane, data.port
                local new_idx = lane_idx
                new_lane_ports[new_idx][new_recipe_idx] = port:update_idx(new_idx)
                -- TODO: lane.item.name
                local item_name = "normal"
                -- update flowrates (down lanes middle and upper, up lanes upper only)
                if port.port_type == PortType.FLUID_INPUT or
                    port.port_type == PortType.ITEM_INPUT then
                    if lane.priority == LanePriority.LOW then
                        item_name = "low"
                    end
                    new_flowrate_data[new_idx][new_recipe_idx].middle_flow = new_flowrate_data[new_idx][new_recipe_idx]
                        .middle_flow - recipe.inputs[item_name]
                    new_flowrate_data[new_idx][new_recipe_idx].upper_flow = new_flowrate_data[new_idx][new_recipe_idx]
                        .upper_flow - recipe.inputs[item_name]
                else
                    if lane.priority == LanePriority.HIGH then
                        item_name = "high"
                    end
                    new_flowrate_data[new_idx][new_recipe_idx].upper_flow = new_flowrate_data[new_idx][new_recipe_idx]
                        .upper_flow + recipe.outputs[item_name]
                end
            end

            for lane_idx = 1, #lanes.lanes do
                local flow = new_flowrate_data[lane_idx][new_recipe_idx].upper_flow
                new_flowrate_data[lane_idx][new_recipe_idx + 1] = FlowInfo.new(
                    full_recipe.timescale, flow, flow, flow
                )
            end
            table.insert(new_recipes, recipe)
            new_recipe_idx = new_recipe_idx + 1
        else -- not buffer
            -- calculate where the constraint is.  Constraint is given by a fraction of the recipe the input / output can handle
            local fraction_remaining = 1.0
            ---@type table<int, int>
            local lane_replacement = {} -- used to replace the lane ports
            -- there have been some problems with eps here, so make it bigger
            while fraction_remaining > eps * 100 do
                local constraint = fraction_remaining
                for _, data in pairs(recipe_lane_ports) do
                    local lane_idx, lane, port = data.lane_idx, data.lane, data.port
                    ---@type Lane?
                    local current_lane = lane
                    if port.port_type == PortType.FLUID_INPUT or
                        port.port_type == PortType.ITEM_INPUT or
                        port.port_type == PortType.FUEL then
                        if lane.direction == LaneDirection.UP then
                            -- -- print("case 1")
                            -- if new_flowrate_data[current_lane.idx][new_recipe_idx] == nil then
                            --     print(new_recipe_idx)
                            --     print(Dump(current_lane[current_lane.idx]))
                            -- end
                            while (
                                    current_lane ~= nil
                                    and math.abs(
                                        new_flowrate_data[current_lane.idx][new_recipe_idx].lower_flow
                                    )
                                    < 0.0001
                                ) do
                                -- -- print("case 1 recurse")
                                -- if current_lane.next_lane == nil then
                                --     print("Next lane is nil, recipe_idx is " ..
                                --         recipe_idx .. " current lane is " .. current_lane.idx)
                                --     print(recipe.recipe.name)
                                --     print(Dump(new_flowrate_data[current_lane.idx][new_recipe_idx]))
                                --     print(Dump(current_lane))
                                --     print("fraction remaining: " .. fraction_remaining)
                                --     print("eps: " .. eps)
                                -- end
                                current_lane = current_lane.next_lane
                                -- if current_lane and new_flowrate_data[current_lane.idx] == nil then
                                --     print("new recipe " .. new_recipe_idx)
                                --     print("current lane " .. current_lane.idx)
                                --     print("Number of lanes " .. #lanes.lanes)
                                -- elseif current_lane and new_flowrate_data[current_lane.idx][new_recipe_idx] == nil then
                                --     print(new_recipe_idx)
                                --     print(Dump(current_lane[current_lane.idx]))
                                -- end
                            end
                        else
                            -- print("case 2")
                            while (
                                    current_lane ~= nil
                                    and math.abs(
                                        new_flowrate_data[current_lane.idx][new_recipe_idx].upper_flow
                                    )
                                    < eps
                                ) do
                                current_lane = current_lane.next_lane
                            end
                        end
                    elseif lane.direction == LaneDirection.DOWN then
                        -- print("case 3")
                        while (
                                current_lane ~= nil
                                and math.abs(
                                    new_flowrate_data[current_lane.idx][new_recipe_idx].lower_flow
                                )
                                < eps
                            ) do
                            current_lane = current_lane.next_lane
                        end
                    else
                        -- print("case 4")
                        while (
                                current_lane ~= nil
                                and math.abs(
                                    math.abs(
                                        new_flowrate_data[current_lane.idx][new_recipe_idx].lower_flow
                                    )
                                    - full_config:get_max_flowrate(
                                        lane.item.item_type, full_recipe.timescale
                                    )
                                    * full_config.max_bundle_size
                                )
                                < eps
                            ) do
                            current_lane = current_lane.next_lane
                        end
                    end
                    if current_lane == nil then
                        --- we have an error here, dump the flowrate to file
                        ---@type RecipeInfo[]
                        local final_recipes = {}
                        for recipe_idx = #new_recipes, 1, -1 do
                            table.insert(final_recipes, new_recipes[recipe_idx])
                        end
                        -- print(Dump(final_recipes))
                        local new_full_recipe = full_recipe:set_recipes(final_recipes)
                        -- print(#lanes.lanes)
                        -- print(#new_full_recipe.recipes)
                        -- print(#new_flowrate_data)
                        local debug_flowrate = FullFlowInfo.new(lanes, new_full_recipe)
                        debug_flowrate.data = new_flowrate_data
                        ---@type table<int, table<int, FlowInfo>>
                        local final_flowrate_data = {}
                        for lane_idx, data in pairs(new_flowrate_data) do
                            for recipe_idx, value in pairs(data) do
                                if final_flowrate_data[lane_idx] == nil then
                                    final_flowrate_data[lane_idx] = {}
                                end
                                final_flowrate_data[lane_idx][#new_recipes - recipe_idx + 1] = value
                            end
                        end
                        local new_flowrate = FullFlowInfo.new(lanes.lanes, new_full_recipe)
                        new_flowrate.data = final_flowrate_data
                        new_flowrate:round_values(1e-4)
                        -- print(Dump(new_flowrate_data))
                        full_config.bus_debug_logger:save_flowrate(final_recipes, lanes, new_flowrate.data, full_config,
                            false, "ERROR flowrate output")
                        error("Current lane is None.  Reamaining: " ..
                            fraction_remaining .. ", constraint: " .. constraint)
                    end
                    lane_replacement[lane_idx] = current_lane.idx
                    local lane_available
                    local template_requests
                    if port.port_type == PortType.FLUID_INPUT or
                        port.port_type == PortType.ITEM_INPUT or
                        port.port_type == PortType.FUEL then
                        lane_available = new_flowrate_data[current_lane.idx][new_recipe_idx].lower_flow
                        template_requests = recipe.inputs[port.item_name]
                        if template_requests == nil then
                            error(string.format("Template requests for %s (input) is nil: [%s]", port.item_name,
                                Dump(recipe.inputs)))
                        end
                        -- TODO down lane
                    else
                        -- for outputs we look at what is free in the lane
                        if lane.direction == LaneDirection.DOWN then
                            lane_available = -new_flowrate_data[current_lane.idx][new_recipe_idx].lower_flow
                        else
                            lane_available = (
                                full_config:get_max_flowrate(
                                    lane.item.item_type, full_recipe.timescale
                                )
                                * full_config.max_bundle_size
                                - new_flowrate_data[current_lane.idx][new_recipe_idx].lower_flow
                            )
                        end
                        template_requests = recipe.outputs[port.item_name]
                        if template_requests == nil then
                            error(string.format("Template requests for %s (output) is nil: [%s] port: [%s]",
                                port.item_name,
                                Dump(recipe.outputs), Dump(port)))
                        end
                    end

                    local max_flow_rate = full_config:get_max_flowrate(
                        lane.item.item_type, full_recipe.timescale
                    )
                    constraint = math.min(
                        constraint,
                        lane_available / template_requests,
                        max_flow_rate / template_requests
                    )
                    if constraint < eps then
                        -- we love to have errors here
                        -- print(Dump({ lane = lane.idx, next = lane.next_lane.idx }))
                        -- print(Dump({
                        --     constraint = constraint,
                        --     lane_available = lane_available,
                        --     max_flow_rate = max_flow_rate,
                        --     template_requests = template_requests
                        -- }))
                        error("Constraint is too small")
                    end
                end
                -- scale recipe
                local new_recipe = recipe:scale_recipe(constraint)
                -- add it to recipe list
                table.insert(new_recipes, new_recipe)

                -- calculate lane ports
                for _, data in pairs(recipe_lane_ports) do
                    local lane_idx, lane, port = data.lane_idx, data.lane, data.port
                    local new_idx = lane_replacement[lane_idx]
                    new_lane_ports[new_idx][new_recipe_idx] = port:update_idx(new_idx)
                    if port.port_type == PortType.FLUID_INPUT or
                        port.port_type == PortType.ITEM_INPUT or
                        port.port_type == PortType.FUEL then
                        new_flowrate_data[new_idx][new_recipe_idx].middle_flow = new_flowrate_data[new_idx]
                            [new_recipe_idx].middle_flow -
                            new_recipe.inputs[lane.item.name]
                        new_flowrate_data[new_idx][new_recipe_idx].upper_flow = new_flowrate_data[new_idx]
                            [new_recipe_idx].upper_flow -
                            new_recipe.inputs[lane.item.name]
                    else
                        new_flowrate_data[new_idx][new_recipe_idx].upper_flow = new_flowrate_data[new_idx]
                            [new_recipe_idx].upper_flow +
                            new_recipe.outputs[lane.item.name]
                    end
                end

                -- calculate flowrates - using this recipes input and output we update the lanes
                for lane_idx = 1, #lanes.lanes do
                    local flow = new_flowrate_data[lane_idx][new_recipe_idx].upper_flow
                    new_flowrate_data[lane_idx][new_recipe_idx + 1] = FlowInfo.new(
                        full_recipe.timescale, flow, flow, flow
                    )
                end

                new_recipe_idx = new_recipe_idx + 1
                fraction_remaining = fraction_remaining - constraint
            end
        end
    end

    local total_num_recipes = #new_recipes


    -- now we reverse all the recipes - lane ports need their recipe_idx key changed
    -- new_flowrate_data needs its recipe_idx key changed
    -- recipes need to be reversed
    ---@type RecipeInfo[]
    local final_recipes = {}
    for recipe_idx = #new_recipes, 1, -1 do
        table.insert(final_recipes, new_recipes[recipe_idx])
    end

    ---@type table<int, table<int, LanePort>>
    local final_lane_ports = {}
    for lane_idx, data in pairs(new_lane_ports) do
        for recipe_idx, value in pairs(data) do
            if final_lane_ports[lane_idx] == nil then
                final_lane_ports[lane_idx] = {}
            end
            final_lane_ports[lane_idx][total_num_recipes - recipe_idx + 1] = value
        end
    end

    ---@type table<int, table<int, FlowInfo>>
    local final_flowrate_data = {}
    for lane_idx, data in pairs(new_flowrate_data) do
        for recipe_idx, value in pairs(data) do
            if final_flowrate_data[lane_idx] == nil then
                final_flowrate_data[lane_idx] = {}
            end
            final_flowrate_data[lane_idx][total_num_recipes - recipe_idx + 1] = value
        end
    end


    local new_full_recipe = full_recipe:set_recipes(final_recipes)
    local new_flowrate = FullFlowInfo.new(lanes.lanes, new_full_recipe)
    new_flowrate.data = final_flowrate_data
    new_flowrate:round_values()
    return new_full_recipe, final_lane_ports, new_flowrate
end

---Using the FullFlowInfo update the buffers in full recipe with their flowrates
---@param full_recipe FullRecipe
---@param lane_ports table<int, table<int, LanePort>>
---@param flowrate FullFlowInfo
function Algorithms.add_flowrates_to_buffers(full_recipe, lane_ports, flowrate)
    for recipe_idx, recipe in ipairs(full_recipe.recipes) do
        if recipe.recipe_type == RecipeType.BUFFER then
            for lane_idx, data in pairs(lane_ports) do
                if data[recipe_idx] ~= nil then
                    local lane = flowrate.lanes[lane_idx]
                    if lane.priority == LanePriority.LOW then
                        recipe.inputs["low"] = recipe.inputs["low"] - flowrate.data[lane_idx][recipe_idx].upper_flow
                    elseif lane.priority == LanePriority.NORMAL_DOWN then
                        recipe.inputs["normal"] = recipe.inputs["normal"] -
                            flowrate.data[lane_idx][recipe_idx].upper_flow
                    elseif lane.priority == LanePriority.HIGH then
                        recipe.outputs["high"] = recipe.outputs["high"] +
                            flowrate.data[lane_idx][recipe_idx].upper_flow
                    elseif lane.priority == LanePriority.NORMAL_UP then
                        recipe.outputs["normal"] = recipe.outputs["normal"] +
                            flowrate.data[lane_idx][recipe_idx].upper_flow
                    else
                        error("Unexpected priority: " .. lane.priority)
                    end
                end
            end
            if math.abs(Array_sum(recipe.inputs) - Array_sum(recipe.outputs)) > eps then
                error("Buffer values do not balance for buffer: " .. recipe.recipe.name)
            end
        end
    end
end

---Convert a collection of lanes into intervals
---@param lanes LaneCollection
---@param max_value int
---@param full_config FullConfig
---@returna {left: number, right:number, ignore:bool|nil}[]
function Algorithms.lanes_to_intervals(lanes, max_value, full_config)
    local output = {}
    local ALPHA = 0.3
    local BETA = 0.6
    for _, lane in ipairs(lanes.lanes) do
        local left = max_value
        local right = 0
        -- starts from the top down
        for idx = 1, #lane.construct_range do
            -- for idx, status in ipairs(lane.construct_range) do
            local status = lane.construct_range[#lane.construct_range - idx + 1]
            if status == LaneStatus.BEGIN then
                left = math.min(left, idx + BETA)
                -- left = idx + BETA
                -- right = idx + 1
                right = math.max(right, idx + 1)
            elseif status == LaneStatus.END then
                left = math.min(left, idx)
                right = math.max(right, idx + ALPHA)
                -- right = idx + ALPHA
            elseif status == LaneStatus.CONSTRUCT then
                left = math.min(left, idx)
                right = math.max(right, idx + 1)
            elseif status == LaneStatus.EMPTY then
                -- do nothing
            elseif status == LaneStatus.INPUT then
                left = math.min(left, 1)
                right = math.max(right, 2)
            elseif status == LaneStatus.OUTPUT then
                left = math.min(left, idx)
                right = math.max(right, idx + 1)
            elseif status == LaneStatus.BYPRODUCT then
                left = math.min(left, idx)
                right = math.max(right, idx + 1)
            elseif status == LaneStatus.BOTH then
                error("LaneStatus BOTH should not occur at this stage")
            elseif status == LaneStatus.OUTPUT_BEGIN then
                left = math.min(left, idx)
                right = math.max(right, idx + BETA)
                -- right = idx + BETA
            elseif status == LaneStatus.INPUT_END then
                left = 1
                right = 1 + ALPHA
            end
        end
        if left > right then error("Lane has no construction") end
        if not (lane:is_output() and not OutputStyle.generate_output_lane(full_config.output_style)) then
            table.insert(output, { left = left, right = right })
        else
            table.insert(output, { left = left, right = right, ignore = true })
        end
    end
    return output
end
