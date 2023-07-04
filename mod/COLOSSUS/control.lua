require("factorio.remote")
require("factorio.main")
require("factorio.factoryplanner")
require("factorio.events")
require("factorio.template_editor")

require("common.utils.utils")
require("common.config.config")

if script.active_mods["gvv"] then require("__gvv__.gvv")() end

---Call the given function in a protected manner
---@param func fun(event: any)
local function protected_call(func)
    return function(event)
        local to_call = function() return func(event) end
        local successful, error_message, _ret = xpcall(to_call, debug.traceback)
        if not successful then
            if event.player_index then
                game.players[event.player_index].print(error_message)
            end
        end
    end
end

script.on_init(protected_call(GuiEvents.on_init))
script.on_event(defines.events.on_player_created, protected_call(GuiEvents.on_player_created))
script.on_event(defines.events.on_player_removed, protected_call(GuiEvents.on_player_removed))
script.on_event(defines.events.on_gui_click, protected_call(GuiEvents.on_gui_click))
script.on_event(defines.events.on_gui_elem_changed, protected_call(GuiEvents.on_gui_elem_changed))
script.on_event(defines.events.on_gui_value_changed, protected_call(GuiEvents.on_gui_value_changed))
script.on_event("colossus_toggle_interface", protected_call(GuiEvents.colossus_toggle_interface))
script.on_event(defines.events.on_gui_closed, protected_call(GuiEvents.on_gui_closed))
script.on_event(defines.events.on_gui_selected_tab_changed, protected_call(GuiEvents.on_gui_selected_tab_changed))
script.on_event(defines.events.on_lua_shortcut, protected_call(GuiEvents.on_lua_shortcut))
