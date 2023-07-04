--- various dialogs

Dialog = {}

---@enum DialogType
DialogType = {
    Warning = "warning",
    Import = "import",
    Export = "export"
}

function Dialog.show_screen(player, player_global, dialog_type, data, tag)
    local screen_element = player.gui.screen
    local dialog_frame = screen_element.add { type = "frame", name = "colossus_dialog_frame", direction =
    "vertical" }
    dialog_frame.style.size = { 424, 338 }
    dialog_frame.auto_center = true
    player_global.elements.dialog_frame = dialog_frame
    dialog_frame.style.top_padding = 4
    dialog_frame.style.right_padding = 8
    dialog_frame.style.left_padding = 8
    dialog_frame.add { type = 'flow', name = 'header', direction = 'horizontal' }
    dialog_frame.header.drag_target = dialog_frame
    dialog_frame.header.style.vertically_stretchable = false
    dialog_frame.header.add { type = 'label', name = 'title', caption = { "colossus.dialog." .. dialog_type }, style =
    'frame_title' }
    dialog_frame.header.title.drag_target = dialog_frame
    local drag = dialog_frame.header.add { type = 'empty-widget', name = 'dragspace', style = 'draggable_space_header' }
    drag.drag_target = dialog_frame
    drag.style.right_margin = 8
    drag.style.height = 24
    drag.style.horizontally_stretchable = true
    drag.style.vertically_stretchable = true
    local close = dialog_frame.header.add { type = 'sprite-button', name = 'dialog_close', sprite = 'utility/close_white', style =
    'frame_action_button', mouse_button_filter = { 'left' } }

    if dialog_type == DialogType.Export then
        local content = dialog_frame.add { type = "text-box", name = "colossus_dialog_text", text = data, word_wrap = true, read_only = true,
            style = "colossus_controls_textfield" }
        content.style.size = { 400, 250 }
        content.word_wrap = true
        content.read_only = true
        local button_flow = dialog_frame.add { type = "flow", direction = "horizontal" }
        local empty = button_flow.add { type = "empty-widget" }
        empty.style.size = { 284, 0 }
        button_flow.add { type = "button", caption = { "colossus.dialog.ok" }, style = "dialog_button", name =
        "dialog_close_button" }
    elseif dialog_type == DialogType.Import then
        local content = dialog_frame.add { type = "text-box", name = "colossus_dialog_text", text = data, word_wrap = true, style =
        "colossus_controls_textfield" }
        content.word_wrap = true
        player_global.elements.dialog_content = content
        content.style.size = { 400, 250 }
        local button_flow = dialog_frame.add { type = "flow", direction = "horizontal" }
        button_flow.add { type = "button", caption = { "colossus.dialog.cancel" }, style = "dialog_button", name =
        "dialog_close_button" }
        local empty = button_flow.add { type = "empty-widget" }
        empty.style.size = { 168, 0 }
        button_flow.add { type = "button", caption = { "colossus.dialog.ok" }, style = "dialog_button", name = tag }
    else
        local content = dialog_frame.add { type = "label", caption = data, text = data }
        content.style.size = { 400, 250 }
        local button_flow = dialog_frame.add { type = "flow", direction = "horizontal" }
        button_flow.add { type = "button", caption = { "colossus.dialog.cancel" }, style = "dialog_button", name =
        "dialog_close_button" }
        local empty = button_flow.add { type = "empty-widget" }
        empty.style.size = { 168, 0 }
        button_flow.add { type = "button", caption = { "colossus.dialog.ok" }, style = "dialog_button", name = tag }
    end

    local content = dialog_frame.add { type = "scroll-pane" }
    content.style.size = { 580, 500 }
end

function Dialog.close_screen(player, player_global)
    local dialog_frame = player_global.elements.dialog_frame or player.gui.screen.colossus_dialog_frame
    dialog_frame.destroy()
    player_global.elements.dialog_frame = nil
end
