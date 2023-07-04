-- represents flow information in the bus

require("common.utils.objects")

local eps = 1e-6

---@alias CrossbarCoordinate {lane: int, recipe: int}
---@alias BundleCoordinate {bundle: int, lane: int}
---@alias FullCrossbarCoordinate {bundle: int, lane: int, recipe: int}

---Represents flow information at a point in a crossbar
---lower flow is below upper flow visually
---@class FlowInfo : BaseClass
---@field timescale int
---@field lower_flow number default 0.0
---@field middle_flow number default 0.0
---@field upper_flow number default 0.0
FlowInfo = InheritsFrom(nil)

---Create a new FlowInfo
---@param timescale int
---@param lower_flow? number default 0.0
---@param middle_flow? number default 0.0
---@param upper_flow? number default 0.0
---@returns FlowInfo
function FlowInfo.new(timescale, lower_flow, middle_flow, upper_flow)
    local self = FlowInfo:create()
    self.timescale = timescale
    self.lower_flow = lower_flow or 0.0
    self.middle_flow = middle_flow or 0.0
    self.upper_flow = upper_flow or 0.0
    return self
end

---Return the max absolute flow over the FlowInfo
---@return number
function FlowInfo:get_max_abs_flow()
    return math.max(math.abs(self.lower_flow), math.abs(self.middle_flow), math.abs(self.upper_flow))
end

---Return a table with number of belts needed for each type of belt
---@param full_config FullConfig
---@return table<string, {lower: number, middle: number, upper:number}>
function FlowInfo:get_number_of_belts_needed(full_config)
    local out = {}
    for belt, speed_per_second in pairs(full_config.game_data.transport_belt_speeds) do
        out[belt] = {
            lower = math.abs(self.lower_flow / self.timescale / speed_per_second),
            middle = math.abs(self.middle_flow / self.timescale / speed_per_second),
            upper = math.abs(self.upper_flow / self.timescale / speed_per_second),
        }
    end
    return out
end

---Return a table with number of pipes needed for each type of pipe
---@param full_config FullConfig
---@return table<string, {lower: number, middle: number, upper:number}>
function FlowInfo:get_number_of_pipes_needed(full_config)
    local out = {}
    for belt, speed_per_second in pairs(full_config.game_data.pipes) do
        out[belt] = {
            lower = math.abs(self.lower_flow / self.timescale / full_config.game_data.pipe_throughput_per_second),
            middle = math.abs(self.middle_flow / self.timescale / full_config.game_data.pipe_throughput_per_second),
            upper = math.abs(self.upper_flow / self.timescale / full_config.game_data.pipe_throughput_per_second),
        }
    end
    return out
end

---Get number of lanes needed for this segment
---@param full_config FullConfig
---@return int
function FlowInfo:get_number_of_lanes_needed(full_config)
    if type == ItemType.ITEM then
        local data = self:get_number_of_belts_needed(full_config)[full_config.belt_item_name]
        return math.ceil(math.max(math.abs(data.lower), math.abs(data.middle), math.abs(data.upper)))
    else
        local data = self:get_number_of_pipes_needed(full_config)[full_config.pipe_item_name]
        return math.ceil(math.max(math.abs(data.lower), math.abs(data.middle), math.abs(data.upper)))
    end
end

---Represents flow for the entire crossbar
---@class FullFlowInfo : BaseClass
---@field lanes Lane[]
---@field full_recipe FullRecipe
---@field num_lanes int
---@field num_recipes int
---@field data table<int, table<int, FlowInfo>>
FullFlowInfo = InheritsFrom(nil)

---Create a new FullFlowInfo
---@param lanes Lane[]
---@param full_recipe FullRecipe
---@return FullFlowInfo
function FullFlowInfo.new(lanes, full_recipe)
    local self = FullFlowInfo:create()
    self.lanes = lanes
    self.full_recipe = full_recipe
    self.num_lanes = #lanes
    self.num_recipes = #full_recipe.recipes
    self.data = {}
    for lane_idx, _ in ipairs(self.lanes) do
        if self.data[lane_idx] == nil then
            self.data[lane_idx] = {}
        end
        for recipe_idx = 1, self.num_recipes do
            self.data[lane_idx][recipe_idx] = FlowInfo.new(full_recipe.timescale, 0.0, 0.0, 0.0)
        end
    end

    return self
end

---Any flows less than eps are sent to 0.0
---@param new_eps float?
function FullFlowInfo:round_values(new_eps)
    if new_eps == nil then
        new_eps = eps
    end
    for lane_idx = 1, self.num_lanes do
        for recipe_idx = 1, self.num_recipes do
            if math.abs(self.data[lane_idx][recipe_idx].lower_flow) < new_eps then
                self.data[lane_idx][recipe_idx].lower_flow = 0.0
            end
            if math.abs(self.data[lane_idx][recipe_idx].middle_flow) < new_eps then
                self.data[lane_idx][recipe_idx].middle_flow = 0.0
            end
            if math.abs(self.data[lane_idx][recipe_idx].upper_flow) < new_eps then
                self.data[lane_idx][recipe_idx].upper_flow = 0.0
            end
        end
    end
end
