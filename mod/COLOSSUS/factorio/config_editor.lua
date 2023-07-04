require("common.config.config")

ConfigEditor = {}
ConfigEditor.UPGRADE_PLANNER_ENABLED = false
ConfigEditor.UNDERGOUND_RESERVED = 2


local function localize_array(base, array)
    local true_array = {}
    for key, value in pairs(array) do
        true_array[value] = key
    end
    local output = {}
    for _, item in ipairs(true_array) do
        table.insert(output, { base .. "." .. item })
    end
    return output
end

function ConfigEditor.create_entity_selector(root, name, type, default)
    local filter = { { filter = "type", type = type },
        { filter = "flag", flag = "hidden", invert = true, mode = "and" } }
    root.add { type = "choose-elem-button", name = name, elem_filters = filter, elem_type =
    "entity" }
    pcall(function() root[name].elem_value = default end)
end

---Convert GUI data to a Config object
---@param config_table any
---@return Config
function ConfigEditor.gui_to_config(config_table)
    local config = Config.new()
    for key, value in pairs(Config.TRANSFORMATION_CONFIG_DATA) do
        config[value.config_name] = config_table[key].elem_value
    end
    config.tile = config_table["choose-tile"].elem_value
    config.tile_style = config_table["tile-style"].selected_index

    config.max_bundle_size = config_table.max_bundle_size_flow.max_bundle_size.slider_value
    config.output_style = config_table["output-style"].selected_index
    config.clocked = config_table.clocked.state
    config.ignore_recipe_loops = config_table.ignore_recipe_loops.state
    config.allow_logistic = config_table.allow_logistic.state

    config.optimizations = {}
    for _, value in pairs(config_table.children) do
        if value.tags and value.tags.type == "optimization" and value.state then
            table.insert(config.optimizations, value.tags.name)
        end
    end

    config.console_logging = config_table.console_logging.state
    config.flowrate_logging = config_table.flowrate_logging.state
    config.always_show_info_dialog = config_table.always_show_info_dialog.state

    -- if some things have been set to nil then replace with defaults
    config:set_defaults()

    return config
end

---Convert a config object to GUI
---@param config Config
---@param config_table any
function ConfigEditor.config_to_gui(config, config_table)
    for key, value in pairs(Config.TRANSFORMATION_CONFIG_DATA) do
        config_table[key].elem_value = config[value.config_name]
    end
    config_table["choose-tile"].elem_value = config.tile
    config_table["tile-style"].selected_index = config.tile_style or 1
    config_table.max_bundle_size_flow.max_bundle_size.slider_value = config.max_bundle_size
    config_table.max_bundle_size_flow.max_bundle_size_flow.caption = config.max_bundle_size
    config_table.clocked.state = config.clocked
    config_table["output-style"].selected_index = config.output_style or 1

    config_table.ignore_recipe_loops.state = config.ignore_recipe_loops
    config_table.allow_logistic.state = config.allow_logistic

    local optimizations = Set.from_array(config.optimizations)
    for _, value in pairs(config_table.children) do
        if value.tags and value.tags.type == "optimization" then
            if optimizations[value.tags.name] == true then
                value.state = true
            else
                value.state = false
            end
        end
    end

    config_table.console_logging.state = config.console_logging
    config_table.flowrate_logging.state = config.flowrate_logging
    config_table.always_show_info_dialog.state = config.always_show_info_dialog
end

function ConfigEditor.show_technique_buttons(technique_frame, player_global)
    if player_global.technique == nil then
        player_global.technique = 1
    end
    player_global.elements.technique_buttons = {}
    for idx, technique in ipairs(TECHNIQUES) do
        local button = technique_frame.add { type = "button", caption = { technique.caption }, tooltip = {
            technique.caption .. "_tooltip" }, tags = {
            index = idx,
            action = "technique_button"
        }, mouse_button_filter = { "left" } }
        if idx == player_global.technique then
            button.style = "colossus_button_selected"
        end
    end
end

local function add_empty_widgets(frame, count)
    for _ = 1, count do
        frame.add { type = "empty-widget" }
    end
end

function ConfigEditor.create_gui(config_frame, player_global)
    -- technique selection
    local technique_frame = config_frame.add { type = "flow", name = "technique_frame", direction = "horizontal" }
    technique_frame.style.bottom_padding = 15
    ConfigEditor.show_technique_buttons(technique_frame, player_global)

    local config_table = config_frame.add { type = "table", name = "config_table", column_count = 4 }
    local current_column = 0
    player_global.elements.config_table = config_table
    -- local belt_config = config_frame.add { type = "flow", name = "belt_config", direction = "horizontal" }
    for key, value in pairs(Config.TRANSFORMATION_CONFIG_DATA) do
        config_table.add { type = "label", caption = { "colossus.config." .. key .. "_caption" }, tooltip = {
            "colossus.config." .. key .. "_tooltip" } }
        ConfigEditor.create_entity_selector(config_table, key, value.type, value.default)
        current_column = (current_column + 1) % 2
    end
    if current_column == 1 then
        add_empty_widgets(config_table, 2)
    end

    -- === Tiles ===
    config_table.add { type = "label", caption = { "colossus.config.tile" }, tooltip = {
        "colossus.config.tile_tooltip" } }
    local filter = { { filter = "blueprintable", mode = "and" } }
    config_table.add { type = "choose-elem-button", name = "choose-tile", elem_filters = filter, elem_type = "tile" }

    config_table.add { type = "label", caption = { "colossus.config.tile_style" }, tooltip = {
        "colossus.config.tile_style_tooltip" } }
    config_table.add { type = "drop-down", name = "tile-style", items = localize_array("colossus.config.tile",
        TileStyle), selected_index = 1 }

    -- === Upgrade Planner ===
    if ConfigEditor.UPGRADE_PLANNER_ENABLED then
        config_table.add { type = "label", caption = { "colossus.config.upgrade_planner" }, tooltip = {
            "colossus.config.upgrade_planner_tooltip" } }
        local upgrade_planner_flow = config_table.add { type = "flow", direction = "horizontal", name =
        "upgrade_planner_flow" }
        player_global.elements.upgrade_planner_flow = upgrade_planner_flow

        ConfigEditor.upgrade_planner_gui(upgrade_planner_flow, player, player_global)
        add_empty_widgets(config_table, 2)
    end

    -- === max bundle size ===
    config_table.add { type = "label", caption = { "colossus.config.max_bundle_size_caption" }, tooltip = {
        "colossus.config.max_bundle_size_tooltip" } }
    local underground_selected = game.entity_prototypes[config_table.underground_chooser]
    local pipe_underground_selected = game.entity_prototypes[config_table.pipe_to_ground_chooser]
    local current_max_bundle_size = 5 - ConfigEditor.UNDERGOUND_RESERVED
    if underground_selected ~= nil then
        current_max_bundle_size = game.entity_prototypes[config_table.underground_chooser].max_underground_distance
        if pipe_underground_selected ~= nil then
            current_max_bundle_size = math.min(current_max_bundle_size,
                game.entity_prototypes[config_table.pipe_to_ground_chooser].max_underground_distance)
        end
    elseif pipe_underground_selected ~= nil then
        current_max_bundle_size = game.entity_prototypes[config_table.pipe_to_ground_chooser].max_underground_distance
    end

    local selected_max_bundle_size = current_max_bundle_size
    if player_global.config ~= nil then
        current_max_bundle_size = math.min(game.entity_prototypes[player_global.config.belt_underground_name]
            .max_underground_distance, game.entity_prototypes[player_global.config.pipe_underground_name]
            .max_underground_distance) - ConfigEditor.UNDERGOUND_RESERVED
        selected_max_bundle_size = player_global.config.max_bundle_size
    end

    local max_bundle_size_flow = config_table.add { type = "flow", direction = "horizontal", name =
    "max_bundle_size_flow" }
    max_bundle_size_flow.add { type = "label", caption = selected_max_bundle_size, name = "max_bundle_size_flow" }
    local slider = max_bundle_size_flow.add { type = "slider", name = "max_bundle_size", minimum_value = 1, maximum_value =
        current_max_bundle_size, discrete_slider = true, value_step = 1, value = selected_max_bundle_size, style =
    "notched_slider" }
    slider.style.left_padding = 4
    max_bundle_size_flow.style.right_padding = 8

    -- === Output style ===
    config_table.add { type = "label", caption = { "colossus.config.output_style" }, tooltip = {
        "colossus.config.output_style_tooltip" } }
    config_table.add { type = "drop-down", items = localize_array("colossus.config.output", OutputStyle), selected_index = 1, name =
    "output-style" }

    -- ==== Bus configuration ===

    config_table.add { type = "label", caption = { "colossus.config.bus_config" }, style = "bold_label" }
    add_empty_widgets(config_table, 3)

    config_table.add { type = "label", caption = { "colossus.config.clocked_caption" }, tooltip = {
        "colossus.config.clocked_tooltip" } }
    config_table.add { type = "checkbox", name = "clocked", state = false }
    config_table.add { type = "label", caption = { "colossus.config.ignore_recipe_loops" }, tooltip = {
        "colossus.config.ignore_recipe_loops_tooltip" } }
    config_table.add { type = "checkbox", name = "ignore_recipe_loops", state = true }
    config_table.add { type = "label", caption = { "colossus.config.allow_logistic" }, tooltip = {
        "colossus.config.allow_logistic_tooltip" } }
    config_table.add { type = "checkbox", name = "allow_logistic", state = false }
    add_empty_widgets(config_table, 2)


    -- ==== Optimizations ===

    config_table.add { type = "label", caption = { "colossus.config.optimizations" }, style = "bold_label" }
    add_empty_widgets(config_table, 3)
    current_column = 0

    for name, _func in pairs(Config.OPTIMIZATIONS) do
        config_table.add { type = "label", caption = { "colossus.config.optimizations." .. name }, tooltip = {
            "colossus.config.optimizations." .. name .. "_tooltip" } }
        config_table.add { type = "checkbox", name = name, state = true, tags = { name = name, type = "optimization" } }
        current_column = (current_column + 1) % 2
    end
    if current_column == 1 then
        add_empty_widgets(config_table, 2)
    end

    -- ==== Logging configuration ===

    config_table.add { type = "label", caption = { "colossus.config.logging" }, style = "bold_label" }
    add_empty_widgets(config_table, 3)
    config_table.add { type = "label", caption = { "colossus.config.console_output" }, tooltip = {
        "colossus.config.console_output_tooltip" } }
    config_table.add { type = "checkbox", name = "console_logging", state = false }
    config_table.add { type = "label", caption = { "colossus.config.log_output" }, tooltip = {
        "colossus.config.log_output_tooltip" } }
    config_table.add { type = "checkbox", name = "flowrate_logging", state = false }
    config_table.add { type = "label", caption = { "colossus.config.info_dialog" }, tooltip = {
        "colossus.config.info_dialog_tooltip" } }
    config_table.add { type = "checkbox", name = "always_show_info_dialog", state = false }
    add_empty_widgets(config_table, 2)

    -- ==== Buttons ===

    local config_buttons = config_frame.add { type = "flow", direction = "horizontal", name =
    "config_buttons_flow" }
    config_buttons.style.top_padding = 8
    config_buttons.add { type = "button", name = "colossus_reset_config", caption = { "colossus.reset_config" } }
    config_buttons.add { type = "button", name = "colossus_save_config", caption = { "colossus.save_config" } }

    return config_table
end
