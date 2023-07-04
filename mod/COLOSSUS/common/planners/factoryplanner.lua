-- For interacting with Factory Planner
-- For integration instructions see the end of this file

require("common.custom_recipe")
require("common.factorio_objects.recipe")
require("common.config.game_data")
require("common.factorio_objects.blueprint")

require("common.utils.objects")
require("common.utils.utils")

local eps = 1e-6

---@class IntermediateInfo : BaseClass
---@field intermediate_name string
---@field intermediate_amount float
---@field input_name string
---@field input_amount float
local IntermediateInfo = InheritsFrom(nil)

---Create a new IntermediateInfo
---@param intermediate_name string
---@param intermediate_amount float
---@param input_name string
---@param input_amount float
---@return IntermediateInfo
function IntermediateInfo.new(intermediate_name, intermediate_amount, input_name, input_amount)
    local self = IntermediateInfo:create()
    self.intermediate_name = intermediate_name
    self.intermediate_amount = intermediate_amount
    self.input_name = input_name
    self.input_amount = input_amount
    return self
end

---Try to remove a temperature from the item name
---@param item string
---@param full_config FullConfig
---@return string
local function try_remove_temperature(item, full_config)
    if full_config.game_data.items[item] ~= nil then
        return item
    end
    local new_name = string.match(item, "(.*)-%d?")
    if new_name == nil then
        return item
    end
    if full_config.game_data.fluids[new_name] == nil then
        -- unknown
        return item
    end
    return new_name
end

assert(string.match("steam-165", "(.*)-%d?") == "steam")

---Load a decoded factory planner export string
---@param object any
---@param full_config FullConfig
---@return FullRecipe
---@return string filename
function Load_factory_planner_bus(object, full_config)
    local recipes = {} -- array of RecipeInfo
    local filename = object.subfactories[1].name

    ---@type table<string, float>
    local inputs = {}
    ---@type table<string, float>
    local outputs = {}
    ---@type table<string, float>
    local byproducts = {}
    ---@type {intermediate_name: string, intermediate_amount: float, input_name: string, input_amount: float}[]
    local intermediates = {}

    local timescale = object.subfactories[1].timescale
    -- inputs, outputs, and byproducts
    local name
    for _, input_item in ipairs(object.subfactories[1].Ingredient.objects) do
        name = try_remove_temperature(input_item.proto.name, full_config)
        inputs[name] = input_item.amount
    end
    for _, output_item in ipairs(object.subfactories[1].Product.objects) do
        name = try_remove_temperature(output_item.proto.name, full_config)
        outputs[name] = output_item.amount
    end
    for _, byproduct_item in ipairs(object.subfactories[1].Byproduct.objects) do
        name = try_remove_temperature(byproduct_item.proto.name, full_config)
        outputs[name] = byproduct_item.amount
    end

    local recipe_line = object.subfactories[1].top_floor.Line.objects
    for _, recipe in ipairs(recipe_line) do
        local name = recipe.recipe.proto.name
        ---@type table<string, float>
        local recipe_inputs = {}
        ---@type table<string, float>
        local recipe_outputs = {}
        ---@type table<string, float>
        local recipe_byproducts = {}
        local item_name

        for _, input_item in ipairs(recipe.Ingredient.objects) do
            item_name = try_remove_temperature(input_item.proto.name, full_config)
            recipe_inputs[item_name] = input_item.amount
        end
        for _, output_item in ipairs(recipe.Product.objects) do
            item_name = try_remove_temperature(output_item.proto.name, full_config)
            recipe_outputs[item_name] = output_item.amount
        end
        for _, byproduct_item in ipairs(recipe.Byproduct.objects) do
            item_name = try_remove_temperature(byproduct_item.proto.name, full_config)
            recipe_byproducts[item_name] = byproduct_item.amount
        end
        -- Now add any fuel that is required
        if recipe.machine.fuel then
            recipe_inputs[recipe.machine.fuel.proto.name] = recipe.machine.fuel.amount
        end

        -- put the byproducts into outputs
        for name, value in pairs(recipe_byproducts) do
            if recipe_outputs[name] == nil then
                recipe_outputs[name] = value
            else
                recipe_outputs[name] = recipe_outputs[name] + value
            end
        end

        local machine_name = recipe.machine.proto.name
        -- Factory Planner patch for Space Exploration
        if machine_name == "se-rocket-launch-pad-silo" then machine_name = "rocket-silo" end

        -- now find all the modules
        -- TODO why is this an array?
        ---@type ModuleCount[]
        local module_data = {} -- array of ModuleCount
        for _, module in pairs(recipe.machine.module_set.modules.objects) do
            table.insert(module_data, ModuleCount.new(module.proto.name, module.amount))
        end

        -- next is beacon data
        ---@type string
        local beacon_name
        ---@type ModuleCount[]
        local beacon_modules = {}
        if recipe.beacon ~= nil then
            beacon_name = recipe.beacon.proto.name
            for _, module in pairs(recipe.beacon.module_set.modules.objects) do
                table.insert(beacon_modules, ModuleCount.new(module.proto.name, module.amount))
            end
        end

        local count = recipe.machine.count -- float TODO this requires mod changes

        local custom_recipe = full_config.custom_recipes[name]
        ---@type Recipe
        local r
        ---@type RecipeType
        local r_type
        local is_custom = false
        if custom_recipe and full_config.custom_recipes_enabled then
            r = custom_recipe.recipe
            r_type = RecipeType.PRODUCE
            is_custom = true

            -- fix up flowrates and remove intermediates
            -- for this we need the productivity of the recipe
            local productivity = 0.0
            for _, module in ipairs(module_data) do
                local module_info = full_config.game_data.items[module.name]
                if module_info then
                    productivity = productivity + module_info.productivity * module.count
                end
            end
            -- now we can fix the flowrates
            Fix_flowrates_for_custom_recipe(custom_recipe, recipe_inputs, productivity)

            -- record the intermediates to fix them later
            for _, modifier in pairs(custom_recipe.intermediates) do
                table.insert(intermediates, {
                    intermediate_name = modifier.new_item,
                    intermediate_amount = recipe_inputs[modifier.base_item]
                        * modifier.multiplier
                        / ((1 + productivity) ^ modifier.exponent),
                    input_name = modifier.base_item,
                    input_amount = recipe_inputs[modifier.base_item]
                })
            end
        else
            -- not custom_recipe
            r = full_config.game_data.recipes[name]
            if r == nil then
                -- error(string.format("Could not find recipe %s", name))
                -- now we build a custom recipe
                local category = recipe.recipe.proto.category
                local ingredients = {}
                local products = {}
                for _, ingredient in pairs(recipe.recipe.proto.ingredients) do
                    -- amounts not actually used here
                    table.insert(ingredients, IngredientItem.new(ingredient.name, ingredient.type))
                end
                for _, product in pairs(recipe.recipe.proto.products) do
                    table.insert(products, IngredientItem.new(product.name, product.type))
                end
                r = Recipe.new(name, ingredients, products, 0.0, category)
            end
            r_type = recipe.recipe.production_type
        end

        -- if we have fuel add it to the recipe
        if recipe.machine.fuel then
            r = Deepcopy(r)
            table.insert(r.inputs, IngredientItem.new(recipe.machine.fuel.proto.name, ItemType.FUEL))
            -- recipe_inputs[recipe.machine.fuel.proto.name] = recipe.machine.fuel.amount
        end

        if String_startswith(r.name, "impostor") then
            if r.name ~= "impostor-silo-rocket-silo-item-satellite" then
                -- don't know how to handle these recipes
                error(string.format("Impostor recipe found: %s\nPlease remove this recipe", r.name))
            end
        end
        -- now add the recipe
        table.insert(recipes, RecipeInfo.new(
            r,
            count,
            r_type,
            machine_name,
            module_data,
            is_custom,
            beacon_name,
            beacon_modules,
            recipe_inputs,
            recipe_outputs
        ))
    end

    -- now we need to go through intermediates and delete the required amount
    -- for intermediate_name, intermediate_amount in intermediates:
    for _, intermediate in ipairs(intermediates) do
        ---@type {input_name: string,  to_add: float}[]
        local new_input_list = {}
        for base_input_name, base_input_amount in pairs(inputs) do
            if base_input_name == intermediate.intermediate_name then
                local to_remove = math.min(intermediate.intermediate_amount, base_input_amount)

                inputs[base_input_name] = inputs[base_input_name] - to_remove
                local to_add = intermediate.input_amount * to_remove / intermediate.intermediate_amount
                intermediate.input_amount = intermediate.input_amount - to_add
                if inputs[intermediate.input_name] == nil then
                    table.insert(new_input_list, { input_name = intermediate.input_name, to_add = to_add })
                else
                    inputs[intermediate.input_name] = inputs[intermediate.input_name] + to_add
                end
            end
        end

        for _, new_input in ipairs(new_input_list) do
            inputs[new_input.input_name] = new_input.to_add
        end

        if math.abs(intermediate.input_amount) > eps then
            ---@type RecipeInfo[]
            local new_recipes = {}
            for _, recipe in ipairs(recipes) do
                if recipe.recipe.name ~= intermediate.intermediate_name then
                    table.insert(new_recipes, recipe)
                else
                    -- we have the recipe.  We know the output count, input_count, num machines.
                    -- we subtract the intermediate_amount from the output and the scale the other numbers accordingly.
                    local scale = (recipe.inputs[intermediate.input_name] - intermediate.input_amount) /
                        recipe.inputs[intermediate.input_name]
                    local scaled_recipe = recipe:scale_recipe(scale)
                    if scaled_recipe.machine_count < eps then
                        full_config.logger:info("Removing recipe " .. recipe.recipe.name)
                    else
                        table.insert(new_recipes, scaled_recipe)
                        -- all recipes have been account for, set input_amount to 0
                        intermediate.input_amount = 0
                    end
                end
            end
            recipes = new_recipes
        end
    end

    -- remove small inputs
    local new_inputs = {}
    for key, value in pairs(inputs) do
        if math.abs(value) > eps then
            new_inputs[key] = value
        end
    end

    return FullRecipe.new(
        recipes,
        new_inputs,
        outputs,
        byproducts,
        timescale
    ), filename
end
