require('common.planners.helmod')

Helmod = {}

---Get a Helmod's global via gvv
---@param player_index uint
---@return any
function Helmod.get_global(player_index)
    local function run()
        return remote.call("__helmod__gvv", "global", player_index)
    end
    local ok, res = pcall(run)
    if not ok then
        -- game.players[player_index].print(res)
        return nil
    end
    return res
end

---Get recipes from Helmod
---@param player_index uint
---@return {recipe_name: string, model_name: string, note: string}[]?
function Helmod.list_factories(player_index)
    local data = Helmod.get_global(player_index)
    local output = {}
    if data then
        for model_name, model_data in pairs(data.models or {}) do
            table.insert(output,
                { recipe_name = Get_helmod_recipe_name(model_data), model_name = model_name, note = model_data.note })
        end
    end
    return output
end

---Can we connect to FactoryPlanner?
---@param player_index uint
---@return boolean
function Helmod.is_active(player_index)
    return Helmod.get_global(player_index) ~= nil
end

---Try to get a factory from FactoryPlanner
---In case of an error prints the error to the players console
---@param player_index uint
---@param model_name string
---@return table?
function Helmod.get_factory(player_index, model_name)
    local data = Helmod.get_global(player_index)
    return data.models[model_name]
end
