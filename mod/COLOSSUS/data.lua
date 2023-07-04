data:extend({
    {
        type = "custom-input",
        name = "colossus_toggle_interface",
        key_sequence = "CONTROL + I",
        order = "a"
    }
})


-- These are some style prototypes that the tutorial uses
-- You don't need to understand how these work to follow along
local styles = data.raw["gui-style"].default

styles["colossus_content_frame"] = {
    type = "frame_style",
    parent = "inside_shallow_frame_with_padding",
    vertically_stretchable = "on",
    horizontally_stretchable = "on"
}

styles["colossus_controls_flow"] = {
    type = "horizontal_flow_style",
    vertical_align = "center",
    horizontal_spacing = 16
}

styles["colossus_controls_textfield"] = {
    type = "textbox_style",
    width = 360,
    vertically_stretchable = "on",
    horizontally_stretchable = "on"
}

styles["colossus_deep_frame"] = {
    type = "frame_style",
    parent = "slot_button_deep_frame",
    vertically_stretchable = "on",
    horizontally_stretchable = "on",
    top_margin = 16,
    left_margin = 8,
    right_margin = 8,
    bottom_margin = 4
}

styles["colossus_button_selected"] = {
    type = "button_style",
    parent = "button",
    default_graphical_set = styles.button.selected_graphical_set,
    disabled_graphical_set = styles.button.selected_graphical_set,
}

data:extend({
    {
        type = "shortcut",
        name = "colossus_toggle_interface",
        action = "lua",
        icon =
        {
            filename = "__COLOSSUS__/graphics/compass-drafting-solid-small.png",
            priority = "extra-high-no-scale",
            size = 32,
            scale = 1,
            flags = { "icon" }
        },
        small_icon =
        {
            filename = "__COLOSSUS__/graphics/compass-drafting-solid-small.png",
            priority = "extra-high-no-scale",
            size = 24,
            scale = 1,
            flags = { "icon" }
        },
        disabled_small_icon =
        {
            filename = "__COLOSSUS__/graphics/compass-drafting-solid-small.png",
            priority = "extra-high-no-scale",
            size = 24,
            scale = 1,
            flags = { "icon" }
        },
        toggleable = false,
        associated_control_input = "colossus_toggle_interface",
    },
})


styles["colossus_sprite-button_inset"] = {
    type = "button_style",
    size = 40,
    padding = 0,
    default_graphical_set = styles.textbox.default_background,
    hovered_graphical_set = styles.rounded_button.clicked_graphical_set,
    clicked_graphical_set = styles.textbox.active_background,
    disabled_graphical_set = styles.rounded_button.disabled_graphical_set
}

styles["colossus_sprite-button_inset_tiny"] = {
    type = "button_style",
    parent = "colossus_sprite-button_inset",
    size = 32
}

styles["colossus_sprite-button_inset_add"] = {
    type = "button_style",
    parent = "colossus_sprite-button_inset_tiny",
    padding = 5
}

styles["colossus_sprite-button_inset_add_slot"] = {
    type = "button_style",
    parent = "colossus_sprite-button_inset_add",
    margin = 4
}

styles["colossus_button_move"] = {
    type = "button_style",
    parent = "button",
    size = 14,
    padding = -1
}

-- Factory Planner sprites:
data:extend({
    {
        filename = "__core__/graphics/gui-new.png",
        type = "sprite",
        name = "col_arrow_up",
        priority = "extra-high-no-scale",
        x = 433,
        y = 473,
        width = 32,
        height = 24,
        scale = 0.5,
        flags = { "icon" }
    },
    {
        filename = "__core__/graphics/gui-new.png",
        type = "sprite",
        name = "col_arrow_down",
        priority = "extra-high-no-scale",
        x = 465,
        y = 473,
        width = 32,
        height = 24,
        scale = 0.5,
        flags = { "icon" }
    },
    {
        filename = "__COLOSSUS__/graphics/compass-drafting-solid-small.png",
        type = "sprite",
        name = "colossus_icon",
        priority = "extra-high-no-scale",
        size = 32,
        -- scale = 0.5,
        flags = { "icon" }
    },
})
