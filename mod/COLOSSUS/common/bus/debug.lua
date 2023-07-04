-- debugging bus generation
-- Debug routines

-- IO = require("io")

---@class DebugLogger : BaseClass
---@field init function
---@field write function
---@field write_timestamp function
---@field close function
DebugLogger = InheritsFrom(nil)

---Create a new DebugLogger
---@param init_fun function
---@param write_fun function
---@param write_timestamp_fun function
---@param close_fun function
---@return DebugLogger
function DebugLogger.new(init_fun, write_fun, write_timestamp_fun, close_fun)
    local self = DebugLogger:create()
    self.init = init_fun
    self.write = write_fun
    self.write_timestamp = write_timestamp_fun
    self.close = close_fun

    return self
end

---@class DebugBus : BaseClass
---@field logger DebugLogger
DebugBus = InheritsFrom(nil)

---Create a new Bus Debug logger
---@param init_fun function
---@param write_fun function
---@param write_timestamp_fun function
---@param close_fun function
---@return DebugBus
function DebugBus.new(init_fun, write_fun, write_timestamp_fun, close_fun)
    local self = DebugBus:create()

    self.logger = DebugLogger.new(init_fun, write_fun, write_timestamp_fun, close_fun)

    self:init()
    return self
end

---Save a flowrate to a file
---@param recipes RecipeInfo[]
---@param lanes LaneCollection
---@param flowrate table<int, table<int, FlowInfo>>
---@param full_config FullConfig
---@param reverse? boolean default false
---@param description? string
function DebugBus:save_flowrate(recipes, lanes, flowrate, full_config, reverse, description)
    self.logger.write_timestamp(description or "Initial flowrate info")
    self.logger.write("\n\n")
    for idx = 1, #recipes do
        local recipe_idx = idx
        if reverse then
            recipe_idx = #recipes - idx + 1
        end
        local recipe = recipes[recipe_idx]
        local name = Pad_string(recipe.recipe.name, 20)
        local upper_line = { name }
        local middle_line = { name }
        local lower_line = { name }

        for lane_idx, lane in ipairs(lanes.lanes) do
            local upper_item_flowrate = flowrate[lane_idx][recipe_idx].upper_flow
            local middle_item_flowrate = flowrate[lane_idx][recipe_idx].middle_flow
            local lower_item_flowrate = flowrate[lane_idx][recipe_idx].lower_flow
            local upper_str = ""
            local middle_str = ""
            local lower_str = ""
            if upper_item_flowrate and upper_item_flowrate ~= 0.0 then
                upper_str = string.format("%10.2f", upper_item_flowrate)
            end
            if middle_item_flowrate and middle_item_flowrate ~= 0.0 then
                middle_str = string.format("%10.2f", middle_item_flowrate)
            end
            if lower_item_flowrate and lower_item_flowrate ~= 0.0 then
                lower_str = string.format("%10.2f", lower_item_flowrate)
            end

            if lane.item.item_type == ItemType.ITEM then
                local num = flowrate[lane_idx][recipe_idx]:get_number_of_belts_needed(full_config)
                    [full_config.belt_item_name]
                if num and num.lower ~= 0.0 then
                    lower_str = string.format("%s %4.2f", lower_str, num.lower)
                end
                if num and num.middle ~= 0.0 then
                    middle_str = string.format("%s %4.2f", middle_str, num.middle)
                end
                if num and num.upper ~= 0.0 then
                    upper_str = string.format("%s %4.2f", upper_str, num.upper)
                end
            else
                for _, num in pairs(flowrate[lane_idx][recipe_idx]:get_number_of_pipes_needed(full_config)) do
                    if num and num.lower ~= 0.0 then
                        lower_str = string.format("%s %4.2f", lower_str, num.lower)
                    end
                    if num and num.middle ~= 0.0 then
                        middle_str = string.format("%s %4.2f", middle_str, num.middle)
                    end
                    if num and num.upper ~= 0.0 then
                        upper_str = string.format("%s %4.2f", upper_str, num.upper)
                    end
                end
            end
            table.insert(upper_line, Pad_string(upper_str, 15))
            table.insert(middle_line, Pad_string(middle_str, 15))
            table.insert(lower_line, Pad_string(lower_str, 15))
        end

        self.logger.write(table.concat(upper_line, " "))
        self.logger.write("\n")
        self.logger.write(table.concat(middle_line, " "))
        self.logger.write("\n")
        self.logger.write(table.concat(lower_line, " "))
        self.logger.write("\n")
    end
    self.logger.write(string.rep(" ", 20))
    self.logger.write(" ")
    for _, lane in ipairs(lanes.lanes) do
        self.logger.write(LanePriority.to_char(lane.priority))
        self.logger.write(Pad_string(lane.item.name, 14))
        self.logger.write(" ")
    end
    self.logger.write("\n\n")
end

---Save construction info to a file
---@param lanes LaneCollection
---@param full_recipe FullRecipe
function DebugBus:save_construction_info_lanes(lanes, full_recipe)
    self.logger.write_timestamp("\nLane construction info")
    self.logger.write("\n\n")
    self.logger.write(string.rep(" ", 21))
    for _, lane in ipairs(lanes.lanes) do
        self.logger.write(Pad_string(lane.item.name, 15))
        self.logger.write(" ")
    end

    self.logger.write("\n")

    for recipe_idx, recipe in ipairs(full_recipe.recipes) do
        self.logger.write(Pad_string(recipe.recipe.name, 20))
        self.logger.write(" ")

        for _, lane in ipairs(lanes.lanes) do
            if lane.construct_range[recipe_idx] == LaneStatus.EMPTY then
                self.logger.write(string.rep(" ", 15))
            else
                self.logger.write(Pad_string(LANESTATUS_STRING[lane.construct_range[recipe_idx]] or "", 15))
            end
            self.logger.write(" ")
        end

        self.logger.write("\n")
    end
    self.logger.write("\n")
end

---Save construction info to a file
---@param bundles OverlappingBundle[]
---@param full_recipe FullRecipe
function DebugBus:save_construction_info_bundles(bundles, full_recipe)
    self.logger.write_timestamp("Lane construction info")
    self.logger.write("\n\n")
    self.logger.write(string.rep(" ", 21))
    for _, overlapping_bundle in ipairs(bundles) do
        self.logger.write(" | ")
        for _, bundle in ipairs(overlapping_bundle.bundles) do
            for _, lane in ipairs(bundle.lanes) do
                self.logger.write(Pad_string(lane.item.name, 15))
                self.logger.write(" ")
            end
        end
    end
    self.logger.write("\n")

    for recipe_idx, recipe in ipairs(full_recipe.recipes) do
        self.logger.write(Pad_string(recipe.recipe.name, 20))
        self.logger.write(" ")
        for _, overlapping_bundle in ipairs(bundles) do
            self.logger.write(" | ")
            for _, bundle in ipairs(overlapping_bundle.bundles) do
                for _, lane in ipairs(bundle.lanes) do
                    if lane.construct_range[recipe_idx] == LaneStatus.EMPTY then
                        self.logger.write(string.rep(" ", 15))
                    else
                        self.logger.write(Pad_string(LANESTATUS_STRING[lane.construct_range[recipe_idx]] or "", 15))
                    end
                    self.logger.write(" ")
                end
            end
        end
        self.logger.write("\n")
    end
    self.logger.write("\n")
end

---Initialize debugging
function DebugBus:init()
    if self.logger == nil then
        error("DebugBus object has not been Initialized")
    end
    self.logger.init()
    self.logger.write_timestamp("Flowrate debug info\n\n")
end

---Finish debugging
function DebugBus:close()
    self.logger.write_timestamp("Finished")
    self.logger.close()
end

---Print the full recipe to a file
---@param recipe FullRecipe
---@param description? string
function DebugBus:print_recipe(recipe, description)
    self.logger.write_timestamp(description or "Initial recipe info")
    self.logger.write("\n\n")
    for recipe_idx, r in ipairs(recipe.recipes) do
        local inputs = {}
        local outputs = {}
        for _, i in ipairs(r.recipe.inputs) do
            table.insert(inputs, i.name .. "[" .. string.format("%2d", r.inputs[i.name] or "-1") .. "]")
        end
        for _, o in ipairs(r.recipe.outputs) do
            table.insert(outputs, o.name .. "[" .. string.format("%2d", r.outputs[o.name] or "-1") .. "]")
        end
        local input_str = table.concat(inputs, ", ")
        local output_str = table.concat(outputs, ", ")
        self.logger.write(string.format("%2d", recipe_idx) ..
            " " ..
            Pad_string(r.recipe.name, 20) ..
            " " .. Pad_string(r.recipe_type, 10) .. " " .. Pad_string(r.machine_count, 4) .. " ")
        self.logger.write(" Inputs:[" .. Pad_string(input_str, 100) .. "] Outputs:[")
        self.logger.write(Pad_string(output_str, 100) .. "]\n")
    end
    self.logger.write("\n\n")
end

---Print the full recipe to a file
---@param lanes LaneCollection
---@param description? string
function DebugBus:print_lanes(lanes, description)
    self.logger.write_timestamp(description or "Initial lane info")
    self.logger.write("\n\n")
    for _, lane in ipairs(lanes.lanes) do
        self.logger.write(Pad_string(lane.name, 20) .. " " .. Pad_string(lane.item.name, 20) .. " ")
        self.logger.write(lane.direction .. " " .. LanePriority.to_char(lane.priority) .. " ")
        local next_lane = "none"
        if lane.next_lane ~= nil then
            next_lane = tostring(lane.next_lane.idx)
        end
        self.logger.write(lane.idx .. " " .. next_lane .. "\n")
    end
    self.logger.write("\n\n")
end

---Save a laneports to a file
---@param recipes FullRecipe
---@param lanes LaneCollection
---@param lane_ports table<integer, table<integer, LanePort>>
---@param description? string
function DebugBus:save_laneports(recipes, lanes, lane_ports, description)
    self.logger.write_timestamp(description or "Initial lane port info")
    self.logger.write("\n\n")
    for recipe_idx = 1, #recipes.recipes do
        local recipe = recipes.recipes[recipe_idx]
        local out = { Pad_string(recipe.recipe.name, 20) }

        for lane_idx = 1, #lanes.lanes do
            local priority = ""
            if lane_ports[lane_idx] and lane_ports[lane_idx][recipe_idx] ~= nil then
                priority = tostring(lane_ports[lane_idx][recipe_idx].flow_rate)
                local port_type = lane_ports[lane_idx][recipe_idx].port_type
                priority = priority .. " " .. tostring(port_type)
            end
            table.insert(out, Pad_string(priority, 15))
        end
        self.logger.write(table.concat(out, " "))
        self.logger.write("\n")
    end
    self.logger.write(string.rep(" ", 20))
    self.logger.write(" ")
    for _, lane in ipairs(lanes.lanes) do
        self.logger.write(LanePriority.to_char(lane.priority))
        self.logger.write(Pad_string(lane.item.name, 14))
        self.logger.write(" ")
    end
    self.logger.write("\n\n")
end

---Save a bypasses to a file
---@param recipes FullRecipe
---@param bundles OverlappingBundle[]
---@param bypasses table<integer, BundleBypass[]>
---@param description? string
function DebugBus:save_bypasses(recipes, bundles, bypasses, description)
    self.logger.write_timestamp(description or "Initial bypass info")
    self.logger.write("\n\n")

    for recipe_idx = 1, #recipes.recipes do
        local recipe = recipes.recipes[recipe_idx]
        local out = { Pad_string(recipe.recipe.name, 20) }

        local data = {}
        for _, bypass in ipairs(bypasses[recipe_idx] or {}) do
            -- if bypass.port.port_type == nil then
            --     print(Dump(bypasses[recipe_idx]))
            --     print(recipe_idx .. "Nil port type" .. bypass.bundle_idx)
            --     data[bypass.bundle_idx] = "(" ..
            --         bypass.port.port_idx .. "," .. bypass.port.priority .. "," .. "???" .. ")"
            -- else
            --     -- if data[bypass.bundle_idx] ~= nil then
            --     --     print(data[bypass.bundle_idx])
            --     -- end
            data[bypass.bundle_idx] = "(" ..
                bypass.port.port_idx .. "," .. bypass.port.priority .. "," .. (bypass.port.port_type or "???") .. ")"
            -- end
        end
        for bundle_idx = 1, #bundles do
            table.insert(out, Pad_string(data[bundle_idx], 10))
        end

        self.logger.write(table.concat(out, " "))
        self.logger.write("\n")
    end

    self.logger.write("\n\n")
end

---Save a lane colors to a file
---@param colors int[]
---@param intervals table[]
function DebugBus:save_lane_colors(colors, intervals)
    self.logger.write_timestamp("Lane coloring\n\n")
    self.logger.write(Dump(intervals))
    self.logger.write(Dump(colors))
    self.logger.write("\n\n")
end

---Save template data to a file
---@param templates any
function DebugBus:save_templates(templates)
    self.logger.write_timestamp("Templates loaded\n\n")
    for _, template in ipairs(templates) do
        local type = "Normal"
        local metadata = template.metadata --[[@as TemplateMetadata]]
        if metadata.custom_recipe then type = "Custom" end
        if metadata.buffer then type = "Buffer" end
        self.logger.write(string.format("%s %d %d %d %d | %d | %s [%s] [%s] %s %s\n",
            Pad_string(template.template_data.name, 30),
            metadata.item_inputs,
            metadata.item_outputs, metadata.fluid_inputs, metadata.fluid_outputs, metadata.num_machines or 0,
            Pad_string(metadata.priority, 4),
            Pad_string(table.concat(Table_keys(metadata.machine_widths), ","), 10),
            Pad_string(table.concat(Table_keys(metadata.machine_heights), ","), 10),
            Pad_string(type, 8),
            Pad_string(table.concat(Table_keys(metadata.crafting_categories), ","), 100))
        )
    end

    self.logger.write("\n\n")
end

---Save what a recipe is looking for
---@param recipe_name string
---@param template_name string
---@param data_table table
function DebugBus:save_recipe_choice(recipe_name, template_name, data_table)
    self.logger.write(string.format("%s: %s | %s\n", Pad_string(recipe_name, 30), Pad_string(template_name, 30),
        Dump(data_table)))
end
