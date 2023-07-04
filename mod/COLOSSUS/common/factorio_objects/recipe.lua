-- represents recipes

require("common.utils.utils")
require("common.factorio_objects.item")
require("common.utils.objects")

---Type of recipe, production or consumption
---@enum RecipeType
RecipeType = {
    PRODUCE = "produce",
    CONSUME = "consume",
    BUFFER = "buffer",
}

--- Recipe: a Factorio recipe
---@class Recipe : BaseClass
---@field name string
---@field inputs IngredientItem[]
---@field outputs IngredientItem[]
---@field loops IngredientItem[]
---@field energy float for energy usage at 1.0 crafting speed
---@field category string
Recipe = InheritsFrom(nil)

---Create a new Recipe
---@param name string
---@param inputs IngredientItem[]
---@param outputs IngredientItem[]
---@param energy float
---@param category string
---@return Recipe
function Recipe.new(name, inputs, outputs, energy, category)
    local self = Recipe:create()
    self.name = name
    self.inputs = inputs
    self.outputs = outputs
    self.energy = energy
    self.category = category
    local loops = {}
    local input_names = {}
    for _, input in ipairs(inputs) do
        input_names[input.name] = true
    end
    for _, output in ipairs(outputs) do
        if input_names[output.name] then
            table.insert(loops, Item.new(output.name, output.item_type))
        end
    end
    self.loops = loops
    -- if #loops > 0 then
    --     print(string.format("Recipe %s has loops: %s", name, Dump(loops)))
    -- end
    return self
end

---Create a Recipe from a JSON object
---@param recipe table
---@return Recipe
function Recipe.from_json(recipe)
    local products = {}
    local fluidbox_index = 1
    for _index, value in ipairs(recipe["products"]) do
        local item = IngredientItem.from_json(value, fluidbox_index)
        if item.item_type == ItemType.FLUID then
            fluidbox_index = fluidbox_index + 1
        end
        table.insert(products, item)
    end
    fluidbox_index = 1
    local ingredients = {}
    for _index, value in ipairs(recipe["ingredients"]) do
        local item = IngredientItem.from_json(value, fluidbox_index)
        if item.item_type == ItemType.FLUID then
            fluidbox_index = fluidbox_index + 1
        end
        table.insert(ingredients, item)
    end
    local result = Recipe.new(recipe["name"], ingredients, products, recipe["energy"], recipe["category"])
    return result
end

---Return an array of the fluidboxes this recipe uses
---@return {type:string, index:int, global_index:int}[]
function Recipe:get_fluidboxes()
    local result = {}
    local max_input_index = 0
    for _, input in ipairs(self.inputs) do
        if input.item_type == ItemType.FLUID then
            table.insert(result, { type = "input", index = input.fluidbox_index, global_index = input.fluidbox_index })
            if max_input_index == nil then
                max_input_index = input.fluidbox_index
            else
                max_input_index = math.max(max_input_index, input.fluidbox_index)
            end
        end
    end
    for _, output in ipairs(self.outputs) do
        if output.item_type == ItemType.FLUID then
            table.insert(result,
                { type = "input", index = output.fluidbox_index, global_index = output.fluidbox_index + max_input_index })
        end
    end
    return result
end

---Get an IngredientItem input by name
---@param name string
---@returns IngredientItem?
function Recipe:get_input(name)
    for _, item in ipairs(self.inputs) do
        if item.name == name then
            return item
        end
    end
end

---Get an IngredientItem output by name
---@param name string
---@returns IngredientItem?
function Recipe:get_output(name)
    for _, item in ipairs(self.outputs) do
        if item.name == name then
            return item
        end
    end
end

local json = {
    name = "test",
    energy = 0.0,
    category = "test_cat",
    products = { { type = "fluid", name = "prod1" }, { type = "fluid", name = "prod2" } },
    ingredients = { { type = "item", name = "ingredient" } }
}
local test_recipe = Recipe.from_json(json)
-- print(Dump(test_recipe))
assert(test_recipe.outputs[1].fluidbox_index == 2 or test_recipe.outputs[2].fluidbox_index == 2)

---ModuleCount: represents a module and count
---@class ModuleCount : BaseClass
---@field name string
---@field count int
ModuleCount = InheritsFrom(nil)

---Create a new ModuleCount
---@param name string
---@param count int
---@return ModuleCount
function ModuleCount.new(name, count)
    local self = ModuleCount:create()
    self.name = name
    self.count = count
    return self
end

---RecipeInfo: Info about a particular recipe
---@class RecipeInfo : BaseClass
---@field recipe Recipe
---@field machine_count float
---@field recipe_type RecipeType
---@field machine_name string
---@field modules ModuleCount[]
---@field custom_recipe boolean
---@field beacon_name? string
---@field beacon_modules ModuleCount[]
---@field inputs table<string, float>
---@field outputs table<string, float>
RecipeInfo = InheritsFrom(nil)

---Create a new REcipeInfo
---@param recipe Recipe
---@param machine_count float
---@param recipe_type RecipeType
---@param machine_name string
---@param modules ModuleCount[]
---@param custom_recipe boolean
---@param beacon_name? string
---@param beacon_modules ModuleCount
---@param inputs table<string, float>
---@param outputs table<string, float>
---@return RecipeInfo
function RecipeInfo.new(recipe, machine_count, recipe_type, machine_name, modules,
                        custom_recipe, beacon_name, beacon_modules, inputs, outputs)
    local self = RecipeInfo:create()
    self.recipe = recipe
    self.machine_count = machine_count
    self.recipe_type = recipe_type
    self.machine_name = machine_name
    self.modules = modules
    self.custom_recipe = custom_recipe
    self.beacon_name = beacon_name
    self.beacon_modules = beacon_modules
    self.inputs = inputs
    self.outputs = outputs
    return self
end

---Scale a RecipeInfo
---@param scale float
---@return RecipeInfo
function RecipeInfo:scale_recipe(scale)
    local new_inputs = {}
    local new_outputs = {}
    for key, value in pairs(self.inputs) do
        new_inputs[key] = value * scale
    end
    for key, value in pairs(self.outputs) do
        new_outputs[key] = value * scale
    end
    return RecipeInfo.new(self.recipe, self.machine_count * scale,
        self.recipe_type, self.machine_name, self.modules, self.custom_recipe,
        self.beacon_name, self.beacon_modules, new_inputs, new_outputs
    )
end

---FullRecipe: A list of recipes in order, with final recipe first
---@class FullRecipe : BaseClass
---@field recipes RecipeInfo[]
---@field inputs table<string, float>
---@field outputs table<string, float>
---@field byproducts table<string, float>
---@field timescale int
---@field item_lookup table<string, IngredientItem>
FullRecipe = InheritsFrom(nil)

---Create a new FullRecipe
---@param recipes RecipeInfo[]
---@param inputs table<string, float>
---@param outputs table<string, float>
---@param byproducts table<string, float>
---@param timescale? int default 60
---@return FullRecipe
function FullRecipe.new(recipes, inputs, outputs, byproducts, timescale)
    local self = FullRecipe:create()
    self.timescale = timescale or 60
    self.recipes = recipes
    self.inputs = Copy(inputs)
    self.outputs = Copy(outputs)
    self.byproducts = Copy(byproducts)

    -- Create an item lookup by finding all items in this full recipe
    local item_lookup = {}
    local function add_to_lookup(data)
        for _, item in ipairs(data) do
            if item_lookup[item.name] == nil then
                item_lookup[item.name] = item
            end
        end
    end
    for _, recipe in ipairs(recipes) do
        add_to_lookup(recipe.recipe.inputs)
        add_to_lookup(recipe.recipe.outputs)
    end

    -- if items appear in the inputs or outputs and we don't have them inside the bus then delete them
    local function delete_unknown_items(data)
        local to_delete = {}
        for name, _ in pairs(data) do
            if item_lookup[name] == nil then
                table.insert(to_delete, name)
            end
        end
        for _, name in ipairs(to_delete) do
            data[name] = nil
        end
    end
    delete_unknown_items(self.inputs)
    delete_unknown_items(self.byproducts)
    delete_unknown_items(self.outputs)

    self.item_lookup = item_lookup
    return self
end

---Get all inputs
---@return Set<string>
function FullRecipe:get_all_inputs()
    local result = {}
    for _key, recipe in pairs(self.recipes) do
        for _key, item in pairs(recipe.recipe.inputs) do
            result[item.name] = true
        end
    end
    for key, _value in pairs(self.inputs) do
        result[key] = true
    end
    return result
end

---get all outputs
---@return Set<string>
function FullRecipe:get_all_outputs()
    local result = {}
    for _key, recipe in pairs(self.recipes) do
        for _key, item in pairs(recipe.recipe.outputs) do
            result[item.name] = true
        end
    end
    for key, _value in pairs(self.outputs) do
        result[key] = true
    end
    return result
end

---get all final outputs
---@return Set<string>
function FullRecipe:get_outputs()
    local all_inputs = self:get_all_inputs()
    local result = {}
    for key, _value in pairs(self:get_all_outputs()) do
        if all_inputs[key] ~= true then
            result[key] = true
        end
    end
    return result
end

---get outputs that are not used as inputs
---@return Set<string>
function FullRecipe:get_outputs_that_are_not_used_as_inputs()
    local all_inputs = self:get_all_inputs()
    local result = {}
    for key, _value in pairs(self.outputs) do
        if all_inputs[key] ~= true then
            result[key] = true
        end
    end
    return result
end

---get non output items
---@return Set<string>
function FullRecipe:get_non_output_items()
    local result = {}
    for _, recipe in pairs(self.recipes) do
        for _, item in pairs(recipe.recipe.inputs) do
            result[item.name] = true
        end
    end
    return result
end

---get unused, which are neither outputs or used by recipes
---@return Set<string>
function FullRecipe:get_unused()
    local seen_items = self:get_non_output_items()
    for item, _ in pairs(self:get_outputs()) do
        seen_items[item] = true
    end
    local result = {}
    for key, _value in pairs(self:get_all_inputs()) do
        if seen_items[key] ~= true then
            result[key] = true
        end
    end
    for key, _value in pairs(self:get_all_outputs()) do
        if seen_items[key] ~= true then
            result[key] = true
        end
    end
    return result
end

---get byproducts, which are an output of a produce recipes and
---ingredients of a consume recipe
---@return Set<string>
function FullRecipe:get_byproducts()
    local produce_outputs = {}
    local consume_inputs = {}
    for _, recipe in pairs(self.recipes) do
        if recipe.recipe_type == RecipeType.PRODUCE then
            for _, item in pairs(recipe.recipe.outputs) do
                produce_outputs[item.name] = true
            end
        end
        if recipe.recipe_type == RecipeType.CONSUME then
            for _, item in pairs(recipe.recipe.inputs) do
                consume_inputs[item.name] = true
            end
        end
    end
    local result = {}
    for item, _value in pairs(produce_outputs) do
        if consume_inputs[item] == true then
            result[item] = true
        end
    end
    return result
end

---get prioritized items, which are an output of a consume recipe and
---an ingredient of a produce recipe - a dual to byproducts
---@return Set<string>
function FullRecipe:get_prioritized_items()
    local produce_inputs = {}
    local consume_outputs = {}
    for _, recipe in pairs(self.recipes) do
        if recipe.recipe_type == RecipeType.PRODUCE then
            for _, item in pairs(recipe.recipe.inputs) do
                produce_inputs[item.name] = true
            end
        end
        if recipe.recipe_type == RecipeType.CONSUME then
            for _, item in pairs(recipe.recipe.outputs) do
                consume_outputs[item.name] = true
            end
        end
    end
    local result = {}
    for item, _value in pairs(produce_inputs) do
        if consume_outputs[item] == true then
            result[item] = true
        end
    end
    return result
end

---get items that are not final outputs, prioritized, or byproducts
---@return Set<string>
function FullRecipe:get_normal_output_items()
    local result = {}
    local byproducts = self:get_byproducts()
    local prioritized = self:get_prioritized_items()
    for key, _ in pairs(self:get_non_output_items()) do
        if byproducts[key] ~= true and prioritized[key] ~= true then
            result[key] = true
        end
    end
    return result
end

---get items that need to be added to the bus
---@return Set<string>
function FullRecipe:get_base_inputs()
    local result = {}
    local all_inputs = self:get_all_inputs()
    local all_outputs = self:get_all_outputs()
    for key, _ in pairs(all_inputs) do
        if all_outputs[key] ~= true then
            result[key] = true
        end
    end
    return result
end

---replace the recipes with a new list.  Shallow clone
---@param recipes RecipeInfo[]
---@return FullRecipe
function FullRecipe:set_recipes(recipes)
    return FullRecipe.new(recipes, self.inputs, self.outputs, self.byproducts, self.timescale)
end

---Return the normal lanes and if they are up or down lanes
---returns a pair of sets of strings
---@return Set<string>
---@return Set<string>
function FullRecipe:get_normal_lane_directions()
    local up_lanes = {}
    local down_lanes = {}
    local byproducts = self:get_byproducts()
    local prioritized = self:get_prioritized_items()

    for _, recipe in pairs(self.recipes) do
        if recipe.recipe_type == RecipeType.PRODUCE then
            for _, item in pairs(recipe.recipe.inputs) do
                if byproducts[item.name] or prioritized[item.name] then
                    up_lanes[item.name] = true
                end
            end
            for _, item in pairs(recipe.recipe.outputs) do
                if byproducts[item.name] and not prioritized[item.name] then
                    down_lanes[item.name] = true
                end
            end
        else
            for _, item in pairs(recipe.recipe.inputs) do
                if not byproducts[item.name] and prioritized[item.name] then
                    up_lanes[item.name] = true
                end
            end
            for _, item in pairs(recipe.recipe.outputs) do
                if byproducts[item.name] or prioritized[item.name] then
                    down_lanes[item.name] = true
                end
            end
        end
    end
    return up_lanes, down_lanes
end

-- TODO test this
