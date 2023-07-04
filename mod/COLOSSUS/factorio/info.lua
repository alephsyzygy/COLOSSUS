--- info screen

require("common.utils.logger")

InfoScreen = {}

function InfoScreen.show_screen(player, player_global, logger)
    local screen_element = player.gui.screen
    local info_frame = screen_element.add { type = "frame", name = "colossus_info_frame", direction =
    "vertical" }
    info_frame.style.size = { 600, 600 }
    info_frame.auto_center = true
    player_global.elements.info_frame = info_frame
    info_frame.style.top_padding = 4
    info_frame.style.right_padding = 8
    info_frame.style.left_padding = 8
    info_frame.add { type = 'flow', name = 'header', direction = 'horizontal' }
    info_frame.header.drag_target = info_frame
    info_frame.header.style.vertically_stretchable = false
    info_frame.header.add { type = 'label', name = 'title', caption = { "colossus.info_title" }, style = 'frame_title' }
    info_frame.header.title.drag_target = info_frame
    local drag = info_frame.header.add { type = 'empty-widget', name = 'dragspace', style = 'draggable_space_header' }
    drag.drag_target = info_frame
    drag.style.right_margin = 8
    drag.style.height = 24
    drag.style.horizontally_stretchable = true
    drag.style.vertically_stretchable = true
    local close = info_frame.header.add { type = 'sprite-button', name = 'info_close', sprite = 'utility/close_white', style =
    'frame_action_button', mouse_button_filter = { 'left' }, tooltip = { "colossus.close_tooltip" } }
    player_global.elements.close = close

    player.opened = info_frame
    local content = info_frame.add { type = "scroll-pane" }
    content.style.size = { 580, 500 }
    local was_an_error = false
    if logger then
        if #logger.error_messages > 0 then
            content.add { type = "label", caption = { "", "[color=red]", { "colossus.info.errors" }, "[/color]" } }
            was_an_error = true
            for _, message in ipairs(logger.error_messages) do
                for _, line in ipairs(Split_string(message, "\n")) do
                    content.add { type = "label", caption = line }
                end
            end
        end
        if #logger.warn_messages > 0 then
            content.add { type = "label", caption = { "", "[color=yellow]", { "colossus.info.warnings" }, "[/color]" } }
            for _, message in ipairs(logger.warn_messages) do
                content.add { type = "label", caption = message }
            end
        end
        if #logger.info_messages > 0 then
            content.add { type = "label", caption = { "", "[color=blue]", { "colossus.info.info" }, "[/color]" } }
            for _, message in ipairs(logger.info_messages) do
                content.add { type = "label", caption = message }
            end
        end
    end
    if not was_an_error then
        info_frame.add { type = "button", name = "colossus_info_proceed", caption = {
            "colossus.create_factoryplanner_blueprint" }, style =
        "confirm_button" }
    else
        info_frame.add { type = "button", name = "colossus_info_close", caption = { "colossus.could_not_create_blueprint" }, style =
        "red_back_button" }
    end
end

function InfoScreen.toggle(player)
    local player_global = global.players[player.index]

    if player_global.elements == nil then
        player_global.elements = {}
    end
    local info_frame = player_global.elements.info_frame or player.gui.screen.colossus_info_frame

    if info_frame == nil then
        local logger = Logger.new()
        InfoScreen.show_screen(player, player_global, logger)
    else
        info_frame.destroy()
        player_global.elements.info_frame = nil
    end
end
