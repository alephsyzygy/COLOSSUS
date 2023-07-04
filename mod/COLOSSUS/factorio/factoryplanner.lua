---@diagnostic disable: undefined-global
---@diagnostic disable: unused-function
--- mod specific settings for interfacing with factoryplanner

FactoryPlanner = {}


local function get_helper(factory)
    local function name_amount(pos)
        local out = {}
        for _, data in pairs(pos.datasets) do
            table.insert(out, { proto = { name = data.proto.name }, amount = data.amount })
        end
        return { objects = out }
    end
    local out = { timescale = factory.timescale }
    out.Ingredient = name_amount(factory.Ingredient)
    out.Byproduct = name_amount(factory.Byproduct)
    out.Product = name_amount(factory.Product)
    local function process_line(lines)
        local result = {}
        for _, line in pairs(lines.datasets) do
            local line_result = {}
            line_result.recipe = {
                proto = { name = line.recipe.proto.name },
                production_type = line.recipe.production_type
            }
            if line.recipe.proto.custom == true then
                line_result.recipe.proto.custom = true
                line_result.recipe.proto.category = line.recipe.proto.category
                line_result.recipe.proto.ingredients = {}
                line_result.recipe.proto.products = {}
                for _, ingredient in pairs(line.recipe.proto.ingredients) do
                    table.insert(line_result.recipe.proto.ingredients,
                        { name = ingredient.name, type = ingredient.type, amount = ingredient.amount })
                end
                for _, product in pairs(line.recipe.proto.products) do
                    table.insert(line_result.recipe.proto.products,
                        { name = product.name, type = product.type, amount = product.amount })
                end
            end
            -- line_result.production_type = line.recipe.production_type
            line_result.Product = name_amount(line.Product)
            line_result.Ingredient = name_amount(line.Ingredient)
            line_result.Byproduct = name_amount(line.Byproduct)
            line_result.machine = { proto = { name = line.machine.proto.name }, count = line.machine.count }
            -- line_result.count = line.machine.count
            line_result.machine.module_set = { modules = name_amount(line.machine.module_set.modules) }
            if line.machine.fuel then
                line_result.machine.fuel = {
                    proto = { name = line.machine.fuel.proto.name },
                    amount = line.machine.fuel.amount
                }
            end
            if line.beacon then
                line_result.beacon = { proto = { name = line.beacon.proto.name } }
                line_result.beacon.amount = line.beacon.amount
                line_result.beacon.module_set = {
                    modules = name_amount(line.beacon.module_set.modules) }
            end
            result[line.gui_position] = line_result
            -- table.insert(result, line_result)
        end
        return result
    end
    out.top_floor = { Line = { objects = process_line(factory.Floor.datasets[1].Line) } }
    out.name = factory.name


    return { subfactories = { out } }
end

---Get a list of all factories in FactoryPlanner
---@param player_index uint
---@return {factory: string, key:int}[]?
function FactoryPlanner.list_factories(player_index)
    local data = FactoryPlanner.get_global(player_index)
    if not data then return nil end

    data = data.players[player_index]
    if not data then return nil end

    local out = {}
    for key, factory in pairs(data.factory.Subfactory.datasets) do
        table.insert(out, { key = key, factory = factory.name })
    end
    return out
end

---Can we connect to FactoryPlanner?
---@param player_index uint
---@return boolean
function FactoryPlanner.is_active(player_index)
    return FactoryPlanner.get_global(player_index) ~= nil
end

---Try to get a factory from FactoryPlanner
---In case of an error prints the error to the players console
---@param player_index uint
---@param factory_index uint
---@return table?
function FactoryPlanner.get_factory(player_index, factory_index)
    local data = FactoryPlanner.get_global(player_index)
    if not data then return nil end
    data = data.players[player_index]
    if not data then return nil end

    local factory = data.factory.Subfactory.datasets[factory_index]
    return get_helper(factory)
end

---Try to get a factory from FactoryPlanner
---In case of an error prints the error to the players console
---@param player_index uint
---@param import_string string
---@return table?
function FactoryPlanner.import_string(player_index, import_string)
    -- local context = data_util.get("context", game.players[player_index])
    --         local first_subfactory = Factory.import_by_string(context.factory, export_string)
    --         return get_helper(first_subfactory)
    local function run()
        return remote.call("__factoryplanner__colossus", "import", player_index, import_string)
    end
    local ok, res = pcall(run)
    if not ok then
        game.players[player_index].print("Something went wrong importing the factory")
        game.players[player_index].print(res)
        return nil
    end
    return res
end

---Get a Factory Planners's global via gvv
---@param player_index uint
---@return any
function FactoryPlanner.get_global(player_index)
    local function run()
        return remote.call("__factoryplanner__gvv", "global", player_index)
    end
    local ok, res = pcall(run)
    if not ok then
        -- game.players[player_index].print(res)
        return nil
    end
    return res
end
