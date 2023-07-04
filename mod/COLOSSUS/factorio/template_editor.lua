require("common.factory_components.tags")

TemplateEditor = {}

TemplateGuiEvents = {}

local function load_tags(player, player_global, x, y)
    if x ~= nil and y ~= nil then
        local entity = CoordTable.get(player_global.elements.coord_table, x, y)
        if not entity or not entity.data then return end
        if entity.data.args == nil then
            entity.data.args = {}
        end
        if entity.data.args.tags == nil then
            entity.data.args.tags = {}
        end
        -- Deepcopy because we want to remember the original in case the user reverts
        player_global.elements.tags = Deepcopy(entity.data.args.tags)
        if entity.data.name then
            for _, e in pairs(player_global.surface.find_entities()) do
                e.destroy()
            end
            local entity_to_preview = player_global.surface.create_entity { name = entity.data.name, position = { 0, 0 }, direction =
                entity.data.direction, force = player.force, create_build_effect_smoke = false }
            player_global.elements.entity_preview.entity = entity_to_preview
            player_global.elements.entity_preview.visible = true
        end
    elseif x ~= nil then
        player_global.elements.tags = Deepcopy(player_global.elements.col_tags[x])
    elseif y ~= nil then
        player_global.elements.tags = Deepcopy(player_global.elements.row_tags[y])
    else
        player_global.elements.tags = Deepcopy(player_global.elements.metadata_tags)
    end
end


local function display_tag_editor(tag_editor, x, y, player, player_global)
    if tag_editor ~= nil then
        tag_editor.clear()

        tag_editor.add { type = "label", caption = { "", { "colossus.template.selected", x or "", y or "" } }, style =
        "frame_title" }

        local tag_table = tag_editor.add { type = "table", column_count = 3, draw_horizontal_line_after_headers = true, draw_vertical_lines = true }
        tag_table.add { type = "empty-widget" }
        tag_table.add { type = "label", caption = "Tag Key" }
        tag_table.add { type = "label", caption = "Tag Value" }
        --- === all tags ===
        local key_widget, value_widget
        local tag_elements = {}
        local new_value
        player_global.elements.tag_elements = tag_elements
        for key, value in pairs(player_global.elements.tags) do
            tag_table.add { type = "sprite-button", sprite = "utility/close_white", style =
            "colossus_sprite-button_inset_add_slot", tags = { action = "delete_tag", key = key }, tooltip = {
                "colossus.template.delete_tag_tooltip" } }
            key_widget = tag_table.add { type = "textfield", text = key, tags = { action = "tag_key", key = key } }
            new_value = value
            if value == "" or value == true then
                new_value = "true"
            end
            value_widget = tag_table.add { type = "textfield", text = new_value, tags = {
                action = "tag_value",
                key = key
            } }
            -- save these for later use
            table.insert(tag_elements, { key = key, key_widget = key_widget, value_widget = value_widget })
        end

        --- === tag editor buttons ===
        tag_table.add { type = "empty-widget" }
        tag_table.add { type = "sprite-button", sprite = "utility/add", style =
        "colossus_sprite-button_inset_add_slot", mouse_button_filter = { "left" }, name = "add_tag", tooltip = {
            "colossus.template.new_tag_tooltip" } }
        local tag_buttons = tag_editor.add { type = "flow", direction = "horizontal" }
        tag_buttons.add { type = "button", caption = { "colossus.template.revert_tag_changes" }, tooltip = {
            "colossus.template.revert_tag_changes_tooltip" }, name = "revert_tags", mouse_button_filter = { "left" } }
        tag_buttons.add { type = "button", caption = { "colossus.template.save_tags" }, tooltip = {
            "colossus.template.save_tags_toolip" }, name = "save_tags", mouse_button_filter = { "left" } }

        -- now show all available tags
        local keys
        if x ~= nil and y ~= nil then
            keys = EntityTags
        elseif x == nil and y ~= nil then
            keys = RowTags
        elseif x ~= nil and y == nil then
            keys = ColTags
        else
            keys = MetadataTags
        end

        local tag_list = player_global.elements.tag_list
        tag_list.clear()
        for key, value in pairs(keys) do
            tag_list.add { type = "label", caption = key, tooltip = value.description }
        end
    end
end

local function tag_editor_to_table(player, player_global)
    local new_tag_data = {}
    local key, value
    for _, widgets in pairs(player_global.elements.tag_elements) do
        key = widgets.key_widget.text
        if key and key ~= "" then
            value = widgets.value_widget.text
            if value == nil or value == "" then
                value = "true"
            end
            new_tag_data[key] = value
        end
    end
    return new_tag_data
end


local function draw_entities(player, player_global, table)
    table.clear()
    local number
    number = Table_count(player_global.elements.metadata_tags)
    if number == 0 then number = nil end
    local button = table.add { type = "sprite-button", sprite = "item/blueprint", mouse_button_filter = {
        "left-and-right" }, name = "edit_metadata", tooltip = { "colossus.metadata_tooltip" }, number = number, tags = {
        action = "template_metadata" } }
    local bounds = player_global.elements.template_bounds
    local min_x, max_x, min_y, max_y = bounds.min_x, bounds.max_x, bounds.min_y, bounds.max_y

    for i = min_x, max_x do
        number = Table_count(player_global.elements.col_tags[i])
        if number == 0 then number = nil end
        table.add { type = "sprite-button", sprite = "utility/add", number = number, mouse_button_filter = {
            "left-and-right" }, tags = { action = "template_column", x = i }, tooltip = { "colossus.tag_tooltip" } }
    end
    for j = min_y, max_y do
        number = Table_count(player_global.elements.row_tags[j])
        if number == 0 then number = nil end
        table.add { type = "sprite-button", sprite = "utility/add", mouse_button_filter = { "left-and-right" }, number =
            number, tags = { action = "template_row", y = j }, tooltip = { "colossus.tag_tooltip" } }
        for i = min_x, max_x do
            local entity = CoordTable.get(player_global.elements.coord_table, i, j)
            local sprite = nil
            if entity then
                if entity.data.name == "delete" then
                    sprite = "utility/close_white"
                    table.add { type = "sprite", sprite = "utility/close_white", resize_to_sprite = true }
                else
                    local tag_count
                    if entity.data.args and entity.data.args.tags then
                        tag_count = Table_count(entity.data.args.tags)
                        if tag_count == 0 then tag_count = nil end
                    end
                    local entity_data = game.entity_prototypes[entity.data.name]
                    if game.is_valid_sprite_path("entity/" .. entity_data.name) then
                        sprite = "entity/" .. entity_data.name
                    end

                    table.add { type = "sprite-button", sprite = sprite, number = tag_count, mouse_button_filter = {
                        "left-and-right" }, tags = { action = "template_entity", x = i, y = j }, tooltip = {
                        "colossus.tag_tooltip" } }
                end
            else
                table.add { type = "empty-widget", sprite = sprite }
            end
        end
    end
end

local function save_tags(player, player_global)
    local x, y = player_global.elements.tag_x, player_global.elements.tag_y
    local entity
    local new_tag_data = tag_editor_to_table(player, player_global)
    if x ~= nil and y ~= nil then
        entity = CoordTable.get(player_global.elements.coord_table, x, y)
        if not entity or not entity.data then
            error(string.format("Entity %d, %d not found", x, y))
            return
        end
        if entity.data.args == nil then
            entity.data.args = {}
        end
        entity.data.args.tags = new_tag_data
    elseif x ~= nil then
        player_global.elements.col_tags[x] = new_tag_data
    elseif y ~= nil then
        player_global.elements.row_tags[y] = new_tag_data
    else
        player_global.elements.metadata_tags = new_tag_data
    end

    load_tags(player, player_global, x, y)
    draw_entities(player, player_global, player_global.elements.template_table)
    display_tag_editor(player_global.elements.tag_editor, x, y, player, player_global)
end


function TemplateEditor.editor_gui(frame, player, player_global)
    local overall_flow = frame.add { type = "flow", direction = "horizontal" }
    local scroll = overall_flow.add { type = "scroll-pane", horizontal_scroll_policy = "always", vertial_scroll_policy =
    "always" }
    scroll.style.size = { 800, 600 }
    -- do stuff to the frame here
    local game_data_lookups = Game_data_lookups()
    local game_data = GameData.initialize(game_data_lookups.entities, game_data_lookups.recipes, game_data_lookups.items)
    if game_data == nil then
        error("Could not initialize game data")
    end
    local template = player_global.elements.template_data
    local data = game.json_to_table(game.decode_string(template.blueprint))

    local blueprint = Blueprint:from_obj(data.blueprint)
    player_global.elements.blueprint = data

    local coord_table = blueprint:to_primitive(game_data.size_data).primitive
    player_global.elements.coord_table = coord_table
    -- load rows, cols, metadata here
    player_global.elements.row_tags = template.row_tags or {}
    player_global.elements.col_tags = template.col_tags or {}
    player_global.elements.metadata_tags = template.metadata_tags or {}
    player_global.elements.copied_tags = nil
    player_global.elements.copied_x = nil
    player_global.elements.copied_y = nil

    -- now find width and height
    local min_x, max_x, min_y, max_y
    CoordTable.iterate(coord_table, function(x, y, entity)
        if min_x == nil then min_x = x end
        if max_x == nil then max_x = x end
        if min_y == nil then min_y = y end
        if max_y == nil then max_y = y end
        min_x = math.min(min_x, x)
        max_x = math.max(max_x, x)
        min_y = math.min(min_y, y)
        max_y = math.max(max_y, y)
    end)
    local table = scroll.add { type = "table", column_count = max_x - min_x + 1 + 1 }
    player_global.elements.template_bounds = { min_x = min_x, max_x = max_x, min_y = min_y, max_y = max_y }
    player_global.elements.template_table = table
    draw_entities(player, player_global, table)


    local editor_preview_flow = frame.add { type = "flow", direction = "horizontal" }
    --- === tag editor ===
    local tag_editor = editor_preview_flow.add { type = "scroll-pane" }
    tag_editor.style.size = { 600, 290 }
    player_global.elements.tag_editor = tag_editor
    display_tag_editor()

    --- === entity previewer ===
    local entity_preview = editor_preview_flow.add { type = "entity-preview" }
    entity_preview.visible = true
    entity_preview.style.size = { 200, 200 }

    player_global.elements.entity_preview = entity_preview

    local tag_list_flow = editor_preview_flow.add { type = "flow", direction = "vertical" }
    tag_list_flow.add { type = "label", caption = { "colossus.tag_list" }, style = "frame_title" }
    local tag_list = tag_list_flow.add { type = "scroll-pane" }
    player_global.elements.tag_list = tag_list

    --- === blueprint previewer ===
    local blueprint_scroll = overall_flow.add { type = "scroll-pane", horizontal_scroll_policy = "always", vertial_scroll_policy =
    "always" }
    local blueprint_preview = blueprint_scroll.add { type = "camera", position = { 0, 0 }, zoom = 1.0, surface_index =
        player_global.blueprint_surface.index }
    blueprint_preview.visible = true
    blueprint_preview.style.size = { 800, 675 }
    -- delete all blueprint entries
    for _, e in pairs(player_global.blueprint_surface.find_entities()) do
        e.destroy()
    end
    -- now load blueprint
    local mid_x, mid_y = (max_x - min_x) / 2, (max_y - min_y) / 2
    local inventory = game.create_inventory(1)
    if inventory[1].import_stack("0" .. template.blueprint) == 0 then
        local new_entity
        for idx, e in ipairs(inventory[1].get_blueprint_entities()) do
            new_entity = player_global.blueprint_surface.create_entity { name = e.name, position = e.position, direction =
                e.direction, force = player.force, create_build_effect_smoke = false }
        end
        blueprint_preview.position = { mid_x, mid_y }
        blueprint_preview.zoom = math.min(23 / (2 * mid_x), 18 / (2 * mid_y), 0.75)
        player_global.blueprint_surface.always_day = true
        player_global.blueprint_surface.build_checkerboard({ { min_x - 10, min_y - 10 }, { max_x + 10, max_y + 10 } })
    else
        player.create_local_flying_text({ create_at_cursor = true, text = { "colossus.blueprint_preview_failed" } })
    end
    inventory.destroy()

    --- === save button ===
    local save = frame.add { type = "flow", direction = "horizontal", style =
    "dialog_buttons_horizontal_flow" }
    local save_spacer = save.add { type = "empty-widget", style = "draggable_space_with_no_left_margin" }
    save_spacer.style.size = { 900, 32 }

    save.add { type = "button", name = "colossus_template_save", caption = { "colossus.template.save" }, style =
    "confirm_button" }
end

local function output_template(player, player_global)
    local game_data_lookups = Game_data_lookups()
    local game_data = GameData.initialize(game_data_lookups.entities, game_data_lookups.recipes, game_data_lookups.items)

    local orig_blueprint = player_global.elements.blueprint
    for _, entity_obj in pairs(orig_blueprint.blueprint.entities) do
        local coords = Fix_coord(
            entity_obj.name,
            entity_obj.position.x,
            entity_obj.position.y,
            entity_obj.direction or 0,
            game_data.size_data
        )
        local entity = CoordTable.get(player_global.elements.coord_table, coords.x, coords.y)
        if entity and entity.data and entity.data.args and entity.data.args.tags then
            entity_obj.tags = entity.data.args.tags
        end
    end

    local orig_template = player_global.elements.template_data

    local output = {
        metadata_tags = Deepcopy(player_global.elements.metadata_tags),
        row_tags = Deepcopy(player_global.elements.row_tags),
        col_tags = Deepcopy(player_global.elements.col_tags),
        blueprint = game.encode_string(game.table_to_json(orig_blueprint)),
        name = orig_template.name,
        icons = orig_template.icons,
        description = orig_template.description,
    }

    return output
end

local function get_xy_tags(player_global, x, y)
    if x then
        if y then
            return CoordTable.get(player_global.elements.coord_table, x, y).data.args.tags
        end
        return player_global.elements.col_tags[x]
    end
    if y then
        return player_global.elements.row_tags[y]
    end
    return player_global.elements.metadata_tags
end

local function set_xy_tags(player_global, x, y, tags)
    if x then
        if y then
            CoordTable.get(player_global.elements.coord_table, x, y).data.args.tags = tags
            return
        end
        player_global.elements.col_tags[x] = tags
        return
    end
    if y then
        player_global.elements.row_tags[y] = tags
        return
    end
    player_global.elements.metadata_tags = tags
    return
end

local function handle_copy_paste(player, player_global, event)
    if event.shift and event.button == defines.mouse_button_type.right then
        -- copy
        local tags = event.element.tags
        local new_tags = get_xy_tags(player_global, tags.x, tags.y)
        if new_tags then
            player_global.elements.copied_tags = new_tags
            player_global.elements.copied_x = tags.x
            player_global.elements.copied_y = tags.y
            player.create_local_flying_text({ create_at_cursor = true, text = { "colossus.copied_tags" } })
            draw_entities(player, player_global, player_global.elements.template_table)
        end
    elseif event.shift and event.button == defines.mouse_button_type.left then
        -- paste
        if player_global.elements.copied_tags then
            local tags = event.element.tags
            set_xy_tags(player_global, tags.x, tags.y, player_global.elements.copied_tags)
            player.create_local_flying_text({ create_at_cursor = true, text = { "colossus.pasted_tags" } })
            draw_entities(player, player_global, player_global.elements.template_table)
            if tags.x == player_global.elements.tag_x and tags.y == player_global.elements.tag_y then
                player_global.elements.tags = player_global.elements.copied_tags
                display_tag_editor(player_global.elements.tag_editor, player_global.elements.tag_x,
                    player_global.elements.tag_y, player, player_global)
            end
        end
    end
end

function TemplateGuiEvents.on_gui_click(event)
    local player = game.get_player(event.player_index)
    local player_global = global.players[event.player_index]
    if player == nil then
        return
    end
    if event.element.tags and event.element.tags.action == "template_entity" then
        if event.shift then
            handle_copy_paste(player, player_global, event)
        elseif event.button == defines.mouse_button_type.left then
            local tags = event.element.tags
            load_tags(player, player_global, tags.x, tags.y)
            player_global.elements.tag_x = tags.x
            player_global.elements.tag_y = tags.y
            display_tag_editor(player_global.elements.tag_editor, tags.x, tags.y, player, player_global)
        end
    elseif event.element.tags and event.element.tags.action == "template_column" then
        if event.shift then
            handle_copy_paste(player, player_global, event)
        elseif event.button == defines.mouse_button_type.left then
            local tags = event.element.tags
            player_global.elements.tag_x = tags.x
            player_global.elements.tag_y = nil
            load_tags(player, player_global, tags.x, nil)
            display_tag_editor(player_global.elements.tag_editor, tags.x, nil, player, player_global)
            player_global.elements.entity_preview.entity = nil
        end
    elseif event.element.tags and event.element.tags.action == "template_row" then
        if event.shift then
            handle_copy_paste(player, player_global, event)
        elseif event.button == defines.mouse_button_type.left then
            local tags = event.element.tags
            player_global.elements.tag_x = nil
            player_global.elements.tag_y = tags.y
            load_tags(player, player_global, nil, tags.y)
            display_tag_editor(player_global.elements.tag_editor, nil, tags.y, player, player_global)
            player_global.elements.entity_preview.entity = nil
        end
    elseif event.element.name == "edit_metadata" then
        if event.shift then
            handle_copy_paste(player, player_global, event)
        elseif event.button == defines.mouse_button_type.left then
            player_global.elements.tag_x = nil
            player_global.elements.tag_y = nil
            load_tags(player, player_global, nil, nil)
            display_tag_editor(player_global.elements.tag_editor, nil, nil, player, player_global)
            player_global.elements.entity_preview.entity = nil
        end
    elseif event.element.name == "add_tag" then
        -- need to save current values
        local new_tags = tag_editor_to_table(player, player_global)
        if new_tags["key"] then
            local i = 1
            while new_tags["key" .. tostring(i)] do
                i = i + 1
            end
            new_tags["key" .. tostring(i)] = "value"
        else
            new_tags["key"] = "value"
        end
        player_global.elements.tags = new_tags
        display_tag_editor(player_global.elements.tag_editor, player_global.elements.tag_x, player_global.elements.tag_y,
            player, player_global)
    elseif event.element.name == "revert_tags" then
        load_tags(player, player_global, player_global.elements.tag_x, player_global.elements.tag_x)
        display_tag_editor(player_global.elements.tag_editor, player_global.elements.tag_x, player_global.elements.tag_y,
            player, player_global)
    elseif event.element.name == "save_tags" then
        save_tags(player, player_global)
    elseif event.element.name == "colossus_template_save" then
        -- time to save the blueprint
        local template_data = output_template(player, player_global)
        local idx = player_global.elements.template_index
        player_global.templates[idx] = template_data
        Toggle_template_interface(player)
        Toggle_interface(player)
        player_global.elements.main_frame.colossus_tabs.selected_tab_index = 6
    elseif event.element.tags and event.element.tags.action == "delete_tag" then
        local key = event.element.tags.key
        player_global.elements.tags[key] = nil
        display_tag_editor(player_global.elements.tag_editor, player_global.elements.tag_x, player_global.elements.tag_y,
            player, player_global)
    end
end
