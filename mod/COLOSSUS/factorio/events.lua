require("factorio.remote")
require("factorio.main")
require("factorio.factoryplanner")
require("factorio.helmod")

require("factorio.template_editor")
require("factorio.config_editor")
require("factorio.info")
require("factorio.dialog")

require("common.utils.utils")
require("common.config.config")
require("common.planners.factoryplanner")
require("common.planners.helmod")

require("data.template_data")

local FACTORY_PLANNER_IMPORT_ENABLED = false

GuiEvents = {}

local version = script.active_mods['COLOSSUS']

local function initialize_global(player)
    if global.players == nil then
        global.players = {}
    end
    global.players[player.index] = {
        controls_active = true,
        button_count = 0,
        selected_item = nil,
        elements = {},
        upgrade_planner = nil,
        templates = nil,
    }
end

---Check that a blueprint is valid, i.e. it has 1x1 snap-to-grid
---@param blueprint any
---@return boolean
local function check_blueprint(blueprint)
    local stack = blueprint.export_stack()
    local blueprint_string = stack:sub(2)
    local decode = game.decode_string(blueprint_string)
    if not decode then return false end
    local data = game.json_to_table(decode)
    if data and data.blueprint and data.blueprint["snap-to-grid"] then
        local snap_to_grid = data.blueprint["snap-to-grid"]
        if snap_to_grid.x == 1 and snap_to_grid.y == 1 then
            return true
        end
    end
    -- need to check that grid is 1-1 here
    return false
end

local function format_signal(signal)
    local type = (signal.type == "virtual") and "virtual-signal" or signal.type
    return (type .. "/" .. signal.name)
end

local function upgrade_planner_gui(config_table, player, player_global)
    if player_global.upgrade_planner == nil then
        local upgrade_planner = config_table.add { type = "sprite-button", sprite = "utility/add", style =
        "colossus_sprite-button_inset_add_slot", mouse_button_filter = { "left" }, name = "add_upgrade_planner", tooltip = {
            "colossus.config.add_upgrade_planner_tooltip" } }
    else
        local inventory = game.create_inventory(1)
        local planner_string = player_global.upgrade_planner
        local planner = inventory[1]
        if planner.import_stack(planner_string) == 0 then
            local tooltip = { "", (planner.label or "Upgrade Planner"), { "colossus.config.upgrade_planner_button" } }
            local button = config_table.add { type = "sprite-button", sprite = "item/upgrade-planner", tooltip = tooltip,
                name = "act_upgrade_planner", mouse_button_filter = { "left-and-right" } }

            local icons = planner.blueprint_icons
            if icons then
                local icon_count = #icons
                local flow = button.add { type = "flow", direction = "horizontal", ignored_by_interaction = true }

                if icon_count == 1 then -- from FactoryPlanner
                    local signal = planner.blueprint_icons[1].signal
                    local sprite_icon = flow.add { type = "sprite", sprite = format_signal(signal) }
                    sprite_icon.style.margin = { 7, 0, 0, 7 }
                else
                    flow.style.padding = { 4, 0, 0, 3 }
                    local table = flow.add { type = "table", column_count = 2 }
                    table.style.cell_padding = -4
                    if icon_count == 2 then table.style.top_margin = 7 end
                    for _, icon in pairs(icons) do
                        table.add { type = "sprite", sprite = format_signal(icon.signal) }
                    end
                end
            end
        else
            player.print("Could not import planner")
        end
        inventory.destroy()
    end
end

local function process_blueprint(blueprint)
    local icons = {}
    local export_string = blueprint.export_stack()
    local decode = game.decode_string(export_string:sub(2))
    if not decode then
        error("Cannot decode blueprint.export_stack()")
    end
    local data = game.json_to_table(decode)
    if not data then
        error("Cannot convert JSON to table")
    end

    for _, icon in pairs(blueprint.blueprint_icons) do
        table.insert(icons, format_signal(icon.signal))
    end

    return {
        name = blueprint.label,
        blueprint = blueprint.export_stack():sub(2),
        icons = icons,
        description = data.blueprint.description,
        metadata_tags = {},
        row_tags = {},
        col_tags = {}
    }
end

---Load the default templates into the given array
local function load_default_templates(player_global)
    -- we deepcopy since we don't want the player modifying the backup templates
    player_global.templates = Deepcopy(CONNECTOR_DATA)
end


local function update_template_gui(scroll, player, player_global)
    local table = scroll.add { type = "table", column_count = 9 }
    local num_templates = #player_global.templates
    local enabled
    for idx, template in ipairs(player_global.templates) do
        local disable_editing = false
        if template.metadata_tags.mods ~= nil then
            local required_mods = MetadataTags.mods.get_tag_array(template.metadata_tags)
            for _, mod_name in pairs(required_mods) do
                if game.active_mods[mod_name] == nil then
                    disable_editing = true
                end
            end
        end
        local flow = table.add { type = "flow", direction = "vertical" }
        flow.style.vertical_spacing = 0
        flow.style.top_padding = 2
        flow.style.right_padding = 4
        if idx > 1 then enabled = true else enabled = false end
        flow.add { type = "sprite-button", sprite = "col_arrow_up", style = "colossus_button_move", enabled = enabled, tags = {
            action = "template_up", idx = idx } }
        if idx < num_templates then enabled = true else enabled = false end
        flow.add { type = "sprite-button", sprite = "col_arrow_down", style = "colossus_button_move", enabled = enabled, tags = {
            action = "template_down", idx = idx } }
        table.add { type = "label", caption = template.name }
        table.add { type = "sprite-button", sprite = "item/blueprint", tooltip = { "colossus.template_tooltip",
            (template.name or "Blueprint"), { "colossus.template_button" } }, -- player_global.inventory[idx] },
            tags = { index = idx, action = "act_template_button" }, mouse_button_filter = { "left-and-right" } }

        table.add { type = "sprite-button", sprite = "utility/change_recipe", tooltip = {
            "colossus.template_edit_tooltip" }, style = "slot_sized_button",
            tags = { index = idx, action = "act_template_edit_button" }, mouse_button_filter = { "left-and-right" },
            enabled = not disable_editing }

        -- signals
        for icon_idx = 1, 4 do
            if template.icons[icon_idx] ~= nil then
                if game.is_valid_sprite_path(template.icons[icon_idx]) then
                    local icon = table.add { type = "sprite", sprite = template.icons[icon_idx] }
                else
                    table.add { type = "sprite", sprite = "utility/missing_icon" }
                end
            else
                table.add { type = "empty-widget" }
            end
        end

        --description
        table.add { type = "label", caption = template.description }
    end
end


local function populate_template_gui(frame, player, player_global)
    if player_global.templates == nil then
        load_default_templates(player_global)
    end
    local scroll = frame.add { type = "scroll-pane" }
    scroll.style.size = { 665, 600 }
    player_global.elements.template_editor_flow = scroll

    update_template_gui(scroll, player, player_global)

    local footer = frame.add { type = "flow", direction = "horizontal" }

    footer.add { type = "sprite-button", sprite = "utility/add", style =
    "colossus_sprite-button_inset_add_slot", mouse_button_filter = { "left" }, name = "add_template", tooltip = {
        "colossus.add_template_tooltip" } }
    footer.add { type = "sprite-button", sprite = "utility/import", style =
    "colossus_sprite-button_inset_add_slot", mouse_button_filter = { "left" }, name = "import_template", tooltip = {
        "colossus.import_template_tooltip" } }
    local spacer = footer.add { type = "empty-widget" }
    spacer.style.size = { 500, 32 }
    footer.add { type = "sprite-button", sprite = "utility/reset", style =
    "colossus_sprite-button_inset_add_slot", mouse_button_filter = { "left" }, name = "colossus_reset_templates", tooltip = {
        "colossus.reset_templates_tooltip" } }
    footer.add { type = "sprite-button", sprite = "utility/export", style =
    "colossus_sprite-button_inset_add_slot", mouse_button_filter = { "left" }, name = "export_templates", tooltip = {
        "colossus.export_templates_tooltip" } }
end



local function build_interface(player)
    if global.players == nil then
        initialize_global(player)
    end
    local player_global = global.players[player.index]

    local screen_element = player.gui.screen
    local main_frame = screen_element.add { type = "frame", name = "colossus_main_frame", direction =
    "vertical" }
    main_frame.style.size = { 730, 800 }
    main_frame.auto_center = true
    player_global.elements.main_frame = main_frame
    main_frame.style.top_padding = 4
    main_frame.style.right_padding = 8
    main_frame.style.left_padding = 8
    main_frame.add { type = 'flow', name = 'header', direction = 'horizontal' }
    main_frame.header.drag_target = main_frame
    main_frame.header.style.vertically_stretchable = false
    main_frame.header.add { type = 'label', name = 'title', caption = { "", { "colossus.title" }, ' - v ',
        version }, style = 'frame_title' }
    main_frame.header.title.drag_target = main_frame
    local drag = main_frame.header.add { type = 'empty-widget', name = 'dragspace', style = 'draggable_space_header' }
    drag.drag_target = main_frame
    drag.style.right_margin = 8
    drag.style.height = 24
    drag.style.horizontally_stretchable = true
    drag.style.vertically_stretchable = true
    local close = main_frame.header.add { type = 'sprite-button', name = 'close', sprite = 'utility/close_white', style =
    'frame_action_button', mouse_button_filter = { 'left' }, tooltip = { "colossus.close_tooltip" } }
    player_global.elements.close = close

    player.opened = main_frame
    local colossus_tabs = main_frame.add { type = "tabbed-pane", name = "colossus_tabs" }

    --- === CONFIG ===

    local config_tab = colossus_tabs.add { type = "tab", caption = { "colossus.config" }, name = "config_tab", tooltip = {
        "colossus.tabtooltip.config" } }

    local config_frame = colossus_tabs.add { type = "frame", name = "config_frame", direction = "vertical", style =
    "colossus_content_frame", caption = { "colossus.config" } }
    colossus_tabs.add_tab(config_tab, config_frame)
    player_global.elements.config_frame = config_frame

    local config_table = ConfigEditor.create_gui(config_frame, player_global)

    --- === FACTORY PLANNER ===
    if script.active_mods["factoryplanner"] and FactoryPlanner.is_active(player.index) then
        local factoryplanner_tab = colossus_tabs.add { type = "tab", caption = { "colossus.factoryplanner" }, name =
        "factoryplanner_tab", tooltip = {
            "colossus.tabtooltip.factoryplanner" } }
        local content_frame = colossus_tabs.add { type = "frame", name = "content_frame", direction = "vertical", style =
        "colossus_content_frame", caption = { "colossus.factoryplanner" } }
        colossus_tabs.add_tab(factoryplanner_tab, content_frame)

        -- content_frame.add { type = "button", name = "colossus_refresh_factoryplanner", caption = { "colossus.refresh_factoryplanner" } }
        local colossus_factoryplanner_factories = content_frame.add { type = "list-box", name =
        "colossus_factoryplanner_factories", items = {} }
        player_global.elements.colossus_factoryplanner_factories = colossus_factoryplanner_factories
        colossus_factoryplanner_factories.style.size = { 644, 600 }
        local factory_planner_dialog_buttons_flow = content_frame.add { type = "flow", direction = "horizontal", style =
        "dialog_buttons_horizontal_flow" }
        factory_planner_dialog_buttons_flow.add { type = "empty-widget", style = "draggable_space_with_no_left_margin" }
        factory_planner_dialog_buttons_flow.add { type = "button", name = "colossus_create_factoryplanner_blueprint", caption = {
            "colossus.create_factoryplanner_blueprint" }, style = "confirm_button" }
    end

    --- === FACTORY PLANNER IMPORT ===
    if FACTORY_PLANNER_IMPORT_ENABLED then
        local factoryplanner_import_tab = colossus_tabs.add { type = "tab", caption = { "colossus.factoryplanner_import" }, name =
        "factoryplanner_import_tab", tooltip = { "colossus.tabtooltip.import_factoryplanner" } }
        local factoryplanner_import_frame = colossus_tabs.add { type = "frame", name =
        "factoryplanner_import_content_frame", direction =
        "vertical", style =
        "colossus_content_frame", caption = { "colossus.factoryplanner_import" } }
        colossus_tabs.add_tab(factoryplanner_import_tab, factoryplanner_import_frame)


        local factoryplanner_import_flow = factoryplanner_import_frame.add { type = "flow", name =
        "factoryplanner_import_flow", direction = "horizontal" }
        factoryplanner_import_flow.style.horizontally_stretchable = true
        local factoryplanner_import_textbox = factoryplanner_import_flow.add { type = "text-box", name = "colossus_text", text =
        "", word_wrap = true, style =
        "colossus_controls_textfield" }
        factoryplanner_import_textbox.word_wrap = true
        player_global.elements.factoryplanner_import_textbox = factoryplanner_import_textbox
        factoryplanner_import_frame.add { type = "button", name = "colossus_create_factoryplanner_import_blueprint", caption = {
            "colossus.create_blueprint" }, style = "confirm_button" }
    end
    --- === HELMOD ===

    if script.active_mods["helmod"] and Helmod.is_active(player.index) then
        local helmod_tab = colossus_tabs.add { type = "tab", caption = { "colossus.helmod" }, name = "helmod_tab", tooltip = {
            "colossus.tabtooltip.helmod" } }
        local helmod_frame = colossus_tabs.add { type = "frame", name = "helmod_content_frame", direction = "vertical", style =
        "colossus_content_frame", caption = { "colossus.helmod" } }
        colossus_tabs.add_tab(helmod_tab, helmod_frame)

        local colossus_helmod_factories = helmod_frame.add { type = "list-box", name = "colossus_helmod_factories", items = {} }
        player_global.elements.colossus_helmod_factories = colossus_helmod_factories
        colossus_helmod_factories.style.size = { 644, 600 }
        local helmod_dialog_buttons_flow = helmod_frame.add { type = "flow", direction = "horizontal", style =
        "dialog_buttons_horizontal_flow" }
        helmod_dialog_buttons_flow.add { type = "empty-widget", style = "draggable_space_with_no_left_margin" }
        helmod_dialog_buttons_flow.add { type = "button", name = "colossus_create_helmod_blueprint", caption = {
            "colossus.create_helmod_blueprint" }, style = "confirm_button" }
    end
    --- === HELMOD IMPORT ===

    local helmod_import_tab = colossus_tabs.add { type = "tab", caption = { "colossus.helmod_import" }, name =
    "helmod_import_tab", tooltip = {
        "colossus.tabtooltip.import_helmod" } }
    local helmod_import_frame = colossus_tabs.add { type = "frame", name = "helmod_import_content_frame", direction =
    "vertical", style =
    "colossus_content_frame", caption = { "colossus.helmod_import" } }
    colossus_tabs.add_tab(helmod_import_tab, helmod_import_frame)

    local helmod_import_flow = helmod_import_frame.add { type = "flow", name =
    "helmod_import_flow", direction = "horizontal" }
    helmod_import_flow.style.horizontally_stretchable = true
    local helmod_import_textbox = helmod_import_flow.add { type = "text-box", name = "colossus_text", text = "", word_wrap = true, style =
    "colossus_controls_textfield" }
    helmod_import_textbox.word_wrap = true
    helmod_import_textbox.style.width = 650
    helmod_import_textbox.style.bottom_padding = 8
    player_global.elements.helmod_import_textbox = helmod_import_textbox
    local helmod_import_blueprint_button = helmod_import_frame.add { type = "button", name =
    "colossus_create_helmod_import_blueprint", caption = { "colossus.create_blueprint" }, style = "confirm_button" }
    helmod_import_blueprint_button.style.top_padding = 8

    --- === Template Editor ===
    local template_editor_tab = colossus_tabs.add { type = "tab", caption = { "colossus.template_editor" }, name =
    "helmodr_import_tab", tooltip = { "colossus.tabtooltip.template" } }
    local template_editor_frame = colossus_tabs.add { type = "frame", name = "template_editor_content_frame", direction =
    "vertical", style = "colossus_content_frame", caption = { "colossus.template_editor" } }
    colossus_tabs.add_tab(template_editor_tab, template_editor_frame)

    populate_template_gui(template_editor_frame, player, player_global)

    --- now import config
    if player_global.config ~= nil then
        ConfigEditor.config_to_gui(player_global.config, config_table)
    end
end

local function build_template_interface(player)
    if global.players == nil then
        initialize_global(player)
    end
    local player_global = global.players[player.index]

    local screen_element = player.gui.screen
    local main_frame = screen_element.add { type = "frame", name = "colossus_template_main_frame", direction =
    "vertical" }
    main_frame.style.size = { 1600, 1000 }
    main_frame.auto_center = true
    player_global.elements.main_frame = main_frame
    main_frame.style.top_padding = 4
    main_frame.style.right_padding = 8
    main_frame.style.left_padding = 8
    main_frame.add { type = 'flow', name = 'header', direction = 'horizontal' }
    main_frame.header.drag_target = main_frame
    main_frame.header.style.vertically_stretchable = false
    main_frame.header.add { type = 'label', name = 'title', caption = { "", { "colossus.template.title" }, ' - v ',
        version }, style = 'frame_title' }
    main_frame.header.title.drag_target = main_frame
    local drag = main_frame.header.add { type = 'empty-widget', name = 'dragspace', style = 'draggable_space_header' }
    drag.drag_target = main_frame
    drag.style.right_margin = 8
    drag.style.height = 24
    drag.style.horizontally_stretchable = true
    drag.style.vertically_stretchable = true
    local close = main_frame.header.add { type = 'sprite-button', name = 'close_template', sprite =
    'utility/close_white', style =
    'frame_action_button', mouse_button_filter = { 'left' }, tooltip = { "colossus.template.close_tooltip" } }
    player_global.elements.close = close

    player.opened = main_frame
    TemplateEditor.editor_gui(main_frame, player, player_global)
end

local function import_template(player, player_global, data)
    local decoded = game.decode_string(data)
    if decoded == nil then
        player.print({ "colossus.dialog.template_decode_error" })
        return
    end
    local template = game.json_to_table(decoded)
    if template == nil then
        player.print({ "colossus.dialog.template_parse_error" })
        return
    end

    local blueprint_string = template.blueprint
    if blueprint_string == nil then
        player.print({ "colossus.dialog.template_no_blueprint" })
        return
    end
    local decoded_blueprint = game.decode_string(blueprint_string)
    if decoded_blueprint == nil then
        player.print({ "colossus.dialog.template_blueprint_decode_error" })
        return
    end
    local blueprint_table = game.json_to_table(decoded_blueprint)
    if blueprint_table == nil then
        player.print({ "colossus.dialog.template_blueprint_parse_error" })
        return
    end
    if template.name == nil then
        player.print({ "colossus.dialog.template_no_name" })
        return
    end
    local col_tags = {}
    local row_tags = {}
    for key, value in pairs(template.col_tags or {}) do
        col_tags[tonumber(key)] = value
    end
    for key, value in pairs(template.row_tags or {}) do
        row_tags[tonumber(key)] = value
    end
    template.col_tags = col_tags
    template.row_tags = row_tags
    if template.metadata_tags == nil then template.metadata_tags = {} end
    if template.icons == nil then template.icons = {} end
    if template.description == nil then template.description = {} end
    table.insert(player_global.templates, template)
    player.print({ "colossus.dialog.template_import_success" })
    local template_editor_flow = player_global.elements.template_editor_flow
    template_editor_flow.clear()
    update_template_gui(template_editor_flow, player, player_global)
end

function Toggle_interface(player, keep_elements)
    local player_global = global.players[player.index]

    if player_global.elements == nil then
        player_global.elements = {}
    end
    if player_global.surface == nil then
        player_global.surface = game.create_surface("colussus_mod_colossus")
    end
    if player_global.blueprint_surface == nil then
        player_global.blueprint_surface = game.create_surface("colussus_mod_colossus_blueprint_surface")
        player_global.blueprint_surface.generate_with_lab_tiles = true
        player_global.blueprint_surface.always_day = true
    end
    local main_frame = player_global.elements.main_frame or player.gui.screen.colossus_main_frame

    if main_frame == nil then
        build_interface(player)
    else
        main_frame.destroy()
        if keep_elements ~= true then
            player_global.elements = {}
        end
    end
end

function Toggle_template_interface(player, keep_elements)
    local player_global = global.players[player.index]
    if player_global.elements == nil then
        player_global.elements = {}
    end
    local main_frame = player_global.elements.main_frame or player.gui.screen.colossus_template_main_frame
    player_global.elements.template_data = nil
    player_global.elements.template_index = nil

    if main_frame == nil then
        build_template_interface(player)
    else
        main_frame.destroy()
        if keep_elements ~= true then player_global.elements = {} end
    end
end

function GuiEvents.on_init()
    global.players = {}

    for _, player in pairs(game.players) do
        initialize_global(player)
        build_interface(player)
    end
end

function GuiEvents.on_player_created(event)
    local player = game.get_player(event.player_index)
    initialize_global(player)
end

function GuiEvents.on_player_removed(event)
    global.players[event.player_index] = nil
end

local function update_factoryplanner_factories(player_index, player_global)
    local factories = FactoryPlanner.list_factories(player_index)
    if factories ~= nil then
        if player_global.factoryplanner == nil then
            player_global.factoryplanner = {}
        end
        player_global.factoryplanner.factories = {}
        local items = {}
        for _, data in ipairs(factories) do
            table.insert(items, data.factory)
            table.insert(player_global.factoryplanner.factories, data.key)
        end
        player_global.elements.colossus_factoryplanner_factories.items = items
    end
end

local function update_helmod_factories(player_index, player_global)
    local factories = Helmod.list_factories(player_index)
    if factories ~= nil then
        if player_global.helmod == nil then
            player_global.helmod = {}
        end
        player_global.helmod.factories = {}
        local items = {}
        for _, data in ipairs(factories) do
            table.insert(items, string.format("[recipe=%s] %s  %s", data.recipe_name, data.recipe_name, data.note or ""))
            table.insert(player_global.helmod.factories, data.model_name)
        end
        player_global.elements.colossus_helmod_factories.items = items
    end
end

local function update_blueprint(player, player_global, idx, blueprint)
    local existing_template = player_global.templates[idx]
    local stack = blueprint.export_stack()
    local blueprint_string = stack:sub(2)
    local icons = {}
    local decode = game.decode_string(blueprint_string)
    if not decode then
        error("Cannot decode blueprint.export_stack()")
    end
    local data = game.json_to_table(decode)
    if not data then
        error("Cannot convert JSON to table")
    end

    for _, icon in pairs(blueprint.blueprint_icons) do
        table.insert(icons, format_signal(icon.signal))
    end

    -- update tags here
    local old_entity_tags = CoordTable.new()
    local existing_decode = game.decode_string(existing_template.blueprint)
    if not existing_decode then
        error("Cannot decode existing blueprint")
    end
    for _, entity in pairs(game.json_to_table(existing_decode).blueprint.entities) do
        if entity.tags ~= nil or not Table_empty(entity.tags) then
            CoordTable.set(old_entity_tags, entity.position.x, entity.position.y, entity.tags)
        end
    end
    for _, entity in pairs(data.blueprint.entities) do
        local old_tags = CoordTable.get(old_entity_tags, entity.position.x, entity.position.y)
        if old_tags and not Table_empty(old_tags) then
            -- old replace the tags if there aren't any there at the moment
            if entity.tags == nil or Table_empty(entity.tags) then
                entity.tags = old_tags
            end
        end
    end

    player_global.templates[idx] = {
        name = blueprint.label,
        blueprint = game.encode_string(game.table_to_json(data --[[@as table]])),
        icons = icons,
        description = data.blueprint.description,
        metadata_tags = existing_template.metadata_tags,
        row_tags = existing_template.row_tags,
        col_tags = existing_template.col_tags
    }
end

function GuiEvents.on_gui_click(event)
    local player = game.get_player(event.player_index)
    local player_global = global.players[event.player_index]
    if player == nil then
        return
    end
    if event.element.name == "close" or event.element.name == "colossus_toggle" or event.element.name == "colossus_toggle_interface" then
        Toggle_interface(player)
    elseif event.element.name == "remoteinfo_close" or event.element.name == "colossus_toggle_info" or event.element.name == "colossus_info_close" then
        InfoScreen.toggle(player)
    elseif event.element.name == "dialog_close" or event.element.name == "colossus_dialog_close" or event.element.name == "dialog_close_button" then
        Dialog.close_screen(player, player_global)
    elseif event.element.name == "close_template" or event.element.name == "colossus_template_toggle" or event.element.name == "colossus_toggle_template_interface" then
        Toggle_template_interface(player)
        Toggle_interface(player)
        player_global.elements.main_frame.colossus_tabs.selected_tab_index = 6
    elseif event.element.name == "colossus_info_proceed" then
        InfoScreen.toggle(player)
        Blueprint_to_cursor(player, player_global)
    elseif event.element.name == "colossus_create_factoryplanner_import_blueprint" then
        local text = player_global.elements.factoryplanner_import_textbox.text
        local factory = FactoryPlanner.import_string(event.player_index, text)
        if factory ~= nil then
            game.write_file("factory.data", game.table_to_json(factory))
            -- now we proceed
            local config = ConfigEditor.gui_to_config(player_global.elements.config_table)
            config.technique = player_global.technique
            Toggle_interface(player)
            local function run()
                Main(event.player_index, factory, config, Load_factory_planner_bus)
            end
            local status, err, ret = xpcall(run, debug.traceback)
            if not status then
                game.print(err)
            end
        else
            player.print("Could not get factory")
        end
    elseif event.element.name == "colossus_create_helmod_import_blueprint" then
        local text = player_global.elements.helmod_import_textbox.text
        local factory
        local import_string = function() factory = Import_helmod_string(text) end
        local status, err = pcall(import_string)
        if not status then
            game.print(err)
        elseif factory then
            game.write_file("factory.data", game.table_to_json(factory))
            -- now we proceed
            local config = ConfigEditor.gui_to_config(player_global.elements.config_table)
            config.technique = player_global.technique
            Toggle_interface(player)
            local function run()
                Main(event.player_index, factory, config, Load_helmod_bus)
            end
            local status, err, ret = xpcall(run, debug.traceback)
            if not status then
                game.print(err)
            end
        else
            player.print("Could not load factory")
        end
    elseif event.element.name == "colossus_refresh_factoryplanner" then
        update_factoryplanner_factories(event.player_index, player_global)
    elseif event.element.name == "colossus_create_factoryplanner_blueprint" then
        local factory_index = player_global.elements.colossus_factoryplanner_factories
            .selected_index
        if factory_index > 0 then
            local fp_factory_index = player_global.factoryplanner.factories[factory_index]
            local factory = FactoryPlanner.get_factory(event.player_index, fp_factory_index)
            if factory ~= nil then
                -- now we proceed
                local config = ConfigEditor.gui_to_config(player_global.elements.config_table)
                config.technique = player_global.technique
                Toggle_interface(player)
                local function run()
                    Main(event.player_index, factory, config, Load_factory_planner_bus)
                end
                local status, err, ret = xpcall(run, debug.traceback)
                if not status then
                    game.print(err)
                end
            else
                player.print("Could not get factory")
            end
        end
    elseif event.element.name == "colossus_create_helmod_blueprint" then
        local factory_index = player_global.elements.colossus_helmod_factories
            .selected_index
        if factory_index > 0 then
            local helmod_model_name = player_global.helmod.factories[factory_index]
            local factory = Helmod.get_factory(event.player_index, helmod_model_name)
            if factory ~= nil then
                -- now we proceed
                local config = ConfigEditor.gui_to_config(player_global.elements.config_table)
                config.technique = player_global.technique
                Toggle_interface(player)
                local function run()
                    Main(event.player_index, factory, config, Load_helmod_bus)
                end
                local status, err, ret = xpcall(run, debug.traceback)
                if not status then
                    game.print(err)
                end
            else
                player.print("Could not get factory")
            end
        end
    elseif event.element.name == "colossus_reset_config" then
        player_global.config = nil
        -- rebuild the interface
        Toggle_interface(player)
        Toggle_interface(player)
    elseif event.element.name == "colossus_save_config" then
        player_global.config = ConfigEditor.gui_to_config(player_global.elements.config_table)
    elseif event.element.name == "colossus_reset_templates" then
        local dialog_data = { "colossus.dialog.replace_all_templates" }
        Dialog.show_screen(player, player_global, DialogType.Warning, dialog_data, "colossus_reset_templates_perform")
    elseif event.element.name == "colossus_reset_templates_perform" then
        load_default_templates(player_global)
        player.print({ "colossus.dialog.templates_reset" })
        Dialog.close_screen(player, player_global)
        local template_editor_flow = player_global.elements.template_editor_flow
        template_editor_flow.clear()
        update_template_gui(template_editor_flow, player, player_global)
    elseif event.element.name == "act_upgrade_planner" then
        if event.button == defines.mouse_button_type.left then
            -- left click put into hand
            player.cursor_stack.import_stack(player_global.upgrade_planner)
            Toggle_interface(player)
        elseif event.button == defines.mouse_button_type.right and event.control then
            -- ctrl right click delete
            player_global.upgrade_planner = nil
            local upgrade_planner_flow = player_global.elements.upgrade_planner_flow
            upgrade_planner_flow.clear()
            upgrade_planner_gui(upgrade_planner_flow, player, player_global)
        end
    elseif event.element.name == "add_upgrade_planner" then
        if player.cursor_stack.is_upgrade_item then
            player_global.upgrade_planner = player.cursor_stack.export_stack()
            local upgrade_planner_flow = player_global.elements.upgrade_planner_flow
            upgrade_planner_flow.clear()
            upgrade_planner_gui(upgrade_planner_flow, player, player_global)
            player.clear_cursor()
        else
            player.create_local_flying_text { text = { "colossus.not_upgrade_planner" }, create_at_cursor = true }
        end
    elseif event.element.name == "add_template" then
        if player.cursor_stack.is_blueprint then
            if player.cursor_stack.is_blueprint_setup() then
                if check_blueprint(player.cursor_stack) then
                    table.insert(player_global.templates, process_blueprint(player.cursor_stack))
                    local template_editor_flow = player_global.elements.template_editor_flow
                    template_editor_flow.clear()
                    update_template_gui(template_editor_flow, player, player_global)
                    player.clear_cursor()
                else
                    player.create_local_flying_text { text = { "colossus.blueprint_not_grid" }, create_at_cursor = true }
                end
            else
                player.create_local_flying_text { text = { "colossus.blueprint_not_configured" }, create_at_cursor = true }
            end
        else
            player.create_local_flying_text { text = { "colossus.not_blueprint" }, create_at_cursor = true }
        end
    elseif event.element.tags and event.element.tags.action == "act_template_button" then
        if event.button == defines.mouse_button_type.left then
            -- TODO: check what is in hand, if blueprint then replace (and match tags)
            -- if not blueprint error
            -- if nothing in hand, put this blueprint into hand
            if player.cursor_stack.is_blueprint then
                if player.cursor_stack.is_blueprint_setup() then
                    if check_blueprint(player.cursor_stack) then
                        update_blueprint(player, player_global, event.element.tags.index, player.cursor_stack)
                        local template_editor_flow = player_global.elements.template_editor_flow
                        template_editor_flow.clear()
                        update_template_gui(template_editor_flow, player, player_global)
                        player.clear_cursor()
                    else
                        player.create_local_flying_text { text = { "colossus.blueprint_not_grid" }, create_at_cursor = true }
                    end
                else
                    player.create_local_flying_text { text = { "colossus.blueprint_not_configured" }, create_at_cursor = true }
                end
            else
                local result = player.cursor_stack.import_stack("0" ..
                    player_global.templates[event.element.tags.index].blueprint)
                if result ~= 0 then
                    player.create_local_flying_text { text = { "colossus.could_not_import_blueprint" }, create_at_cursor = true }
                else
                    Toggle_interface(player)
                end
            end
        elseif event.button == defines.mouse_button_type.right and event.control then
            -- ctrl right click delete
            local dialog_data = { "colossus.dialog.template_delete_warning" }
            player_global.elements.delete_template_idx = event.element.tags.index
            Dialog.show_screen(player, player_global, DialogType.Warning, dialog_data, "delete_template_perform")
        end
    elseif event.element.tags and event.element.tags.action == "act_template_edit_button" then
        local idx = event.element.tags.index
        if event.button == defines.mouse_button_type.left and not event.control then
            -- record this index, send the data to the other GUI, toggle this GUI, show the other one
            player_global.elements.template_index = idx
            player_global.elements.template_data = player_global.templates[idx]
            Toggle_interface(player, true)
            build_template_interface(player)
        elseif event.button == defines.mouse_button_type.right and not event.control then
            -- export this template to a string
            local template = player_global.templates[idx]
            local json = game.table_to_json(template)
            local dialog_data = game.encode_string(json)
            Dialog.show_screen(player, player_global, DialogType.Export, dialog_data)
        end
    elseif event.element.tags and event.element.tags.action == "technique_button" then
        player_global.technique = event.element.tags.index
        Toggle_interface(player, false)
        Toggle_interface(player, false)
    elseif event.element.name == "export_templates" then
        player.print("Exporting templates")
        game.write_file("template_data.lua", serpent.block(player_global.templates))
    elseif event.element.name == "import_template" then
        local dialog_data = ""
        Dialog.show_screen(player, player_global, DialogType.Import, dialog_data, "import_template_perform")
    elseif event.element.name == "import_template_perform" then
        local data = player_global.elements.dialog_content.text
        Dialog.close_screen(player, player_global)
        import_template(player, player_global, data)
    elseif event.element.name == "delete_template_perform" then
        table.remove(player_global.templates, player_global.elements.delete_template_idx)
        Dialog.close_screen(player, player_global)
        local template_editor_flow = player_global.elements.template_editor_flow
        template_editor_flow.clear()
        update_template_gui(template_editor_flow, player, player_global)
    elseif event.element.tags and event.element.tags.action == "template_up" then
        local index = event.element.tags.idx
        local selected = player_global.templates[index]
        local other = player_global.templates[index - 1]
        if selected ~= nil and other ~= nil then
            player_global.templates[index - 1] = selected
            player_global.templates[index] = other
            local template_editor_flow = player_global.elements.template_editor_flow
            template_editor_flow.clear()
            update_template_gui(template_editor_flow, player, player_global)
        end
    elseif event.element.tags and event.element.tags.action == "template_down" then
        local index = event.element.tags.idx
        local selected = player_global.templates[index]
        local other = player_global.templates[index + 1]
        if selected ~= nil and other ~= nil then
            player_global.templates[index + 1] = selected
            player_global.templates[index] = other
            local template_editor_flow = player_global.elements.template_editor_flow
            template_editor_flow.clear()
            update_template_gui(template_editor_flow, player, player_global)
        end
    else
        TemplateGuiEvents.on_gui_click(event)
    end
end

function GuiEvents.on_gui_elem_changed(event)
    local player = game.get_player(event.player_index)
    local player_global = global.players[event.player_index]
    if player == nil then
        return
    end
    if event.element.name == "underground_chooser" or event.element.name == "pipe_to_ground_chooser" then
        local pipe_entity = player_global.elements.config_table.pipe_to_ground_chooser.elem_value
        local belt_entity = player_global.elements.config_table.underground_chooser.elem_value
        if pipe_entity == nil then
            pipe_entity = Config.TRANSFORMATION_CONFIG_DATA.pipe_to_ground_chooser.default
        end
        if belt_entity == nil then
            belt_entity = Config.TRANSFORMATION_CONFIG_DATA.underground_chooser.default
        end
        local pipe_max_underground_distance = game.entity_prototypes[pipe_entity].max_underground_distance -
            ConfigEditor.UNDERGOUND_RESERVED
        local belt_max_underground_distance = game.entity_prototypes[belt_entity].max_underground_distance -
            ConfigEditor.UNDERGOUND_RESERVED
        local slider = player_global.elements.config_table
            .max_bundle_size_flow.max_bundle_size
        if not slider then
            return
        end
        local prev_value = slider.slider_value
        local config_frame = player_global.elements.config_frame
        if player_global.config == nil then
            player_global.config = Config.new()
        end
        player_global.config.belt_underground_name = belt_entity
        player_global.config.pipe_underground_name = pipe_entity
        player_global.config.max_bundle_size = math.max(
            math.min(prev_value, belt_max_underground_distance, pipe_max_underground_distance), 1)
        config_frame:clear()

        local config_table = ConfigEditor.create_gui(config_frame, player_global)
        player_global.elements.config_table = config_table
        ConfigEditor.config_to_gui(player_global.config, config_table)
    else
        local chooser_config = Config.TRANSFORMATION_CONFIG_DATA[event.element.name]
        -- reset to default if cleared
        if chooser_config and event.element.elem_value == nil then
            event.element.elem_value = chooser_config.default
        end
    end
end

function GuiEvents.on_gui_value_changed(event)
    local player = game.get_player(event.player_index)
    local player_global = global.players[event.player_index]
    if player == nil then
        return
    end
    if event.element.name == "max_bundle_size" then
        player_global.elements.config_table.max_bundle_size_flow.max_bundle_size_flow.caption = event.element
            .slider_value
        player_global.config.max_bundle_size = event.element
            .slider_value
    end
end

function GuiEvents.colossus_toggle_interface(event)
    local player = game.get_player(event.player_index)
    Toggle_interface(player)
end

function GuiEvents.colossus_toggle_info(event)
    local player = game.get_player(event.player_index)
    InfoScreen.toggle(player)
end

function GuiEvents.colossus_toggle_template_interface(event)
    local player = game.get_player(event.player_index)
    Toggle_template_interface(player)
end

function GuiEvents.on_gui_closed(event)
    if event.element and event.element.name == "colossus_main_frame" then
        local player = game.get_player(event.player_index)
        local player_global = global.players[event.player_index]
        local dialog_frame = player_global.elements.dialog_frame or player.gui.screen.colossus_dialog_frame
        if dialog_frame then
            -- close the dialog and reset player.opened to colossus_main_frame
            Dialog.close_screen(player, player_global)
            player.opened = player.gui.screen.colossus_main_frame
        else
            Toggle_interface(player)
        end
    elseif event.element and event.element.name == "colossus_template_main_frame" then
        local player = game.get_player(event.player_index)
        local player_global = global.players[event.player_index]
        Toggle_template_interface(player)
        Toggle_interface(player)
        player_global.elements.main_frame.colossus_tabs.selected_tab_index = 6
    elseif event.element and event.element.name == "colossus_info_frame" then
        local player = game.get_player(event.player_index)
        InfoScreen.toggle(player)
    elseif event.element and event.element.name == "colossus_dialog_frame" then
        local player = game.get_player(event.player_index)
        local player_global = global.players[event.player_index]
        Dialog.close_screen(player, player_global)
    end
end

function GuiEvents.on_gui_selected_tab_changed(event)
    local element = event.element
    if event.element and event.element.name == "colossus_tabs" then
        if element.tabs[element.selected_tab_index].tab.name == "factoryplanner_tab" then
            local player_global = global.players[event.player_index]
            update_factoryplanner_factories(event.player_index, player_global)
        elseif element.tabs[element.selected_tab_index].tab.name == "helmod_tab" then
            local player_global = global.players[event.player_index]
            update_helmod_factories(event.player_index, player_global)
        end
    end
end

function GuiEvents.on_lua_shortcut(event)
    local player = game.get_player(event.player_index)
    if player == nil then
        return
    end
    if event.prototype_name == "colossus_toggle_interface" then
        Toggle_interface(player)
    end
end
