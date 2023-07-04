require("common.config.full_config")
require("common.factorio_objects.recipe")
require("common.utils.utils")

local deflate = require('lib.deflatelua')

---Load a bus from Helmod
---@param factory_object any
---@param full_config FullConfig
---@return FullRecipe
---@return string filename
function Load_helmod_bus(factory_object, full_config)
    local blocks = {}
    local inputs = {}
    local outputs = {}
    local recipes = {}
    local timescale = factory_object.time
    local filename

    -- calculate ingredients and products for the overall recipe
    for name, data in pairs(factory_object.ingredients) do
        inputs[name] = data.count
    end
    for name, data in pairs(factory_object.products) do
        outputs[name] = data.count
    end
    for _key, value in pairs(factory_object.blocks) do
        table.insert(blocks, value)
    end

    table.sort(blocks, function(b1, b2) return b1.index < b2.index end)
    for _, block in ipairs(blocks) do
        local recipe_type = RecipeType.PRODUCE
        if block.by_product ~= nil and not block.by_product then
            recipe_type = RecipeType.CONSUME
        end

        local current_recipes = {}
        for _, value in pairs(block.recipes) do
            table.insert(current_recipes, value)
        end
        table.sort(current_recipes, function(r1, r2) return r1.index < r2.index end)
        for _, recipe in ipairs(current_recipes) do
            if not filename then
                -- first recipe is the filename
                filename = recipe.name
            end
            local recipe_inputs = {}
            local recipe_outputs = {}
            local machine_name = recipe.factory.name
            local machine_count = recipe.factory.count
            local recipe_data = full_config.game_data.recipes[recipe.name]
            local helmod_recipe_type = recipe.type
            if recipe_data == nil then
                error(string.format("Could not find recipe %s", recipe.name))
            end
            if helmod_recipe_type == "rocket" then
                full_config.logger:error(string.format(
                    "Helmod rocket recipes are not yet supported.  They will be enabled in the near future."))
                error("Helmod rocket recipe is not enabled in the pre-release of COLOSSUS")
            elseif helmod_recipe_type ~= "recipe" then
                full_config.logger:warn(string.format(
                    "Do no know how to handle Helmod recipe %s of type %s, skipping this recipe", recipe
                    .name, helmod_recipe_type))
            else
                for _, ingredient in ipairs(recipe_data.inputs) do
                    recipe_inputs[ingredient.name] = recipe.count * ingredient:get_average_amount()
                end
                for _, product in ipairs(recipe_data.outputs) do
                    recipe_outputs[product.name] = recipe.count *
                        (product:get_average_amount() + product:get_productive_amount() * recipe.factory.effects.productivity)
                end

                local module_data = {}
                for module_name, module_count in pairs(recipe.factory.modules) do
                    table.insert(module_data, ModuleCount.new(module_name, module_count))
                end
                local beacon_name
                local beacon_modules = {}
                if recipe.beacon.count > 0 then
                    beacon_name = recipe.beacon.name
                    for module_name, module_count in pairs(recipe.beacon.modules) do
                        table.insert(beacon_modules, ModuleCount.new(module_name, module_count))
                    end
                end

                -- now check if we need fuel
                local machine_data = full_config.game_data.entities[machine_name]
                if machine_data.burner_prototype or recipe.factory.fuel then
                    local fuel = recipe.factory.fuel or "coal" -- coal seems to be default
                    local fuel_data = full_config.game_data.items[fuel]
                    local fuel_value = fuel_data.fuel_value
                    local energy = recipe.factory.energy
                    local fuel_needed = energy * (1 + recipe.factory.effects.consumption) / recipe.factory.speed *
                        recipe.factory.count * timescale
                    local fuel_count = fuel_needed / fuel_value

                    recipe_inputs[fuel] = fuel_count
                    recipe_data = Deepcopy(recipe_data)
                    table.insert(recipe_data.inputs, IngredientItem.new(fuel, ItemType.FUEL))
                end
                local recipe_info = RecipeInfo.new(recipe_data, machine_count, recipe_type, machine_name,
                    module_data, false, beacon_name, beacon_modules, recipe_inputs, recipe_outputs)
                table.insert(recipes, recipe_info)
            end
        end
    end

    return FullRecipe.new(recipes, inputs, outputs, {}, timescale), filename
end

function Import_helmod_string(import_string)
    local data = import_string:gsub("\r?\n", " ")
    local b64decoded = Base64.decode(data)
    local output = {}
    deflate.gunzip({ input = b64decoded, output = function(byte) table.insert(output, string.char(byte)) end })
    local string_output = table.concat(output)
    local success, factory_object = serpent.load(string_output)
    if success then
        return factory_object
    end
end

function Get_helmod_recipe_name(data)
    local lowest_block_index
    local output
    for _, block in pairs(data.blocks) do
        if lowest_block_index == nil or block.index < lowest_block_index then
            lowest_block_index = block.index
            local lowest_recipe_index
            for _, recipe in pairs(block.recipes) do
                if lowest_recipe_index == nil or recipe.index < lowest_recipe_index then
                    lowest_recipe_index = recipe.index
                    output = recipe.name
                end
            end
        end
    end
    return output
end
